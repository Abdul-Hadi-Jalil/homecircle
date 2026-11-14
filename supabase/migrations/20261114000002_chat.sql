-- Chat is API-written. Historical sender UUIDs survive membership/account removal.
create table public.household_messages (
 id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
 sender_user_id uuid not null, client_message_id uuid not null,
 message_type text not null check(message_type in ('text','image','task_share','system')),
 body text check(length(body)<=4000), reply_to_message_id uuid, linked_task_id uuid,
 request_hash text not null, revision bigint not null default 1 check(revision>0),
 created_at timestamptz not null default clock_timestamp(), updated_at timestamptz not null default clock_timestamp(),
 edited_at timestamptz, deleted_at timestamptz,
 unique(household_id,id), unique(household_id,sender_user_id,client_message_id),
 foreign key(household_id,reply_to_message_id) references public.household_messages(household_id,id),
 foreign key(household_id,linked_task_id) references public.household_tasks(household_id,id),
 check((message_type='text' and body is not null and length(btrim(body))>0 and linked_task_id is null)
  or (message_type='task_share' and linked_task_id is not null)
  or (message_type in ('image','system') and linked_task_id is null))
);
create index chat_history on public.household_messages(household_id,created_at desc,id desc);
create index chat_sender on public.household_messages(household_id,sender_user_id);
create index chat_replies on public.household_messages(household_id,reply_to_message_id);
create index chat_tasks on public.household_messages(household_id,linked_task_id);

create table public.message_reactions (
 id uuid primary key default gen_random_uuid(), household_id uuid not null, message_id uuid not null,
 user_id uuid not null, emoji text not null check(emoji in ('👍','❤️','😂','😮','😢','🙏')),
 created_at timestamptz not null default clock_timestamp(), unique(household_id,message_id,user_id,emoji),
 foreign key(household_id,message_id) references public.household_messages(household_id,id) on delete cascade
);

create table private.chat_uploads (
 id uuid primary key, household_id uuid not null references public.households(id) on delete cascade,
 actor_id uuid not null, client_message_id uuid not null, storage_path text not null unique,
 input_hash text not null, content_hash text not null, size_bytes integer not null check(size_bytes between 1 and 5242880),
 created_at timestamptz not null default clock_timestamp(), expires_at timestamptz not null default(clock_timestamp()+interval '60 seconds'),
 finalized boolean not null default false, abandoned boolean not null default false,
 check(storage_path=household_id::text||'/'||actor_id::text||'/'||id::text||'.jpg')
);
create table public.message_attachments (
 id uuid primary key references private.chat_uploads(id), household_id uuid not null, message_id uuid not null,
 uploaded_by uuid not null, storage_path text not null unique, content_type text not null check(content_type='image/jpeg'),
 size_bytes integer not null check(size_bytes between 1 and 5242880), created_at timestamptz not null default clock_timestamp(),
 removed_at timestamptz,
 foreign key(household_id,message_id) references public.household_messages(household_id,id) on delete cascade,
 check(storage_path=household_id::text||'/'||uploaded_by::text||'/'||id::text||'.jpg')
);
create index chat_attachment_message on public.message_attachments(household_id,message_id);
create function private.validate_chat_attachment() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from private.chat_uploads u join public.household_messages m
   on m.household_id=u.household_id and m.client_message_id=u.client_message_id
   and m.sender_user_id=u.actor_id where u.id=new.id and u.finalized
   and m.id=new.message_id and m.message_type='image' and m.deleted_at is null and not u.abandoned
   and new.household_id=u.household_id and new.uploaded_by=u.actor_id
   and new.storage_path=u.storage_path and new.size_bytes=u.size_bytes) then
   raise check_violation using message='Image is not finalized for this message';
 end if;
 return new;
end $$;
revoke all on function private.validate_chat_attachment() from public,anon,authenticated,homecircle_api;
create trigger chat_attachment_validate before insert on public.message_attachments
 for each row execute function private.validate_chat_attachment();

create table public.chat_task_conversions (
 household_id uuid not null, message_id uuid not null, actor_id uuid not null, client_request_id uuid not null,
 task_id uuid not null, request_hash text not null, created_at timestamptz not null default clock_timestamp(),
 primary key(household_id,actor_id,client_request_id),
 foreign key(household_id,message_id) references public.household_messages(household_id,id) on delete cascade,
 foreign key(household_id,task_id) references public.household_tasks(household_id,id)
);
create index chat_conversion_source on public.chat_task_conversions(household_id,message_id);

-- Durable invalidations also allow recovery of edits/deletions to previously cached history.
create table public.chat_events (
 sequence bigint generated always as identity primary key, event_id uuid not null unique default gen_random_uuid(),
 household_id uuid not null references public.households(id) on delete cascade, message_id uuid not null,
 actor_id uuid, kind text not null, revision bigint not null,
 created_at timestamptz not null default clock_timestamp(), published_at timestamptz,
 foreign key(household_id,message_id) references public.household_messages(household_id,id) on delete cascade
);
create index chat_events_scope on public.chat_events(household_id,sequence);
create index chat_events_message on public.chat_events(household_id,message_id,sequence desc);
create index chat_events_pending on public.chat_events(sequence) where published_at is null;

create function public.chat_actor_name(target uuid, actor uuid) returns text
language sql stable security definer set search_path='' as $$
 select p.display_name from public.profiles p where p.id=actor and private.is_member(target) and (
 exists(select 1 from public.household_members m where m.household_id=target and m.user_id=actor)
 or exists(select 1 from public.household_messages m where m.household_id=target and m.sender_user_id=actor));
$$;
revoke all on function public.chat_actor_name(uuid,uuid) from public,anon,authenticated;
grant execute on function public.chat_actor_name(uuid,uuid) to homecircle_api;

create function private.validate_chat_message() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if TG_OP='INSERT' then
   if new.sender_user_id is distinct from private.current_actor() or not private.is_member(new.household_id)
     or new.message_type='system' then raise check_violation using message='Invalid message actor'; end if;
 else
   if row(new.id,new.household_id,new.sender_user_id,new.client_message_id,new.message_type,new.reply_to_message_id,new.linked_task_id,new.created_at,new.request_hash)
      is distinct from row(old.id,old.household_id,old.sender_user_id,old.client_message_id,old.message_type,old.reply_to_message_id,old.linked_task_id,old.created_at,old.request_hash) then
      raise check_violation using message='Message ownership and identity are immutable';
   end if;
   if old.deleted_at is not null then raise check_violation using message='Deleted message is immutable'; end if;
   new.revision:=old.revision+1; new.updated_at:=clock_timestamp();
 end if;
 return new;
end $$;
revoke all on function private.validate_chat_message() from public,anon,authenticated,homecircle_api;
create trigger chat_message_validate before insert or update on public.household_messages for each row execute function private.validate_chat_message();

create function private.chat_content_check() returns trigger
language plpgsql security definer set search_path='' as $$
declare target uuid; m public.household_messages;
begin
 if TG_TABLE_NAME='household_messages' then target:=coalesce(new.id,old.id); else target:=coalesce(new.message_id,old.message_id); end if;
 select * into m from public.household_messages where id=target;
 if found and m.message_type='image' and m.deleted_at is null and not exists(
   select 1 from public.message_attachments a join private.chat_uploads u on u.id=a.id
   where a.message_id=m.id and a.household_id=m.household_id and a.uploaded_by=m.sender_user_id
   and u.household_id=m.household_id and u.actor_id=m.sender_user_id and u.client_message_id=m.client_message_id
   and u.finalized and not u.abandoned and u.storage_path=a.storage_path and u.size_bytes=a.size_bytes and a.removed_at is null
 ) then raise check_violation using message='Image message requires its finalized image'; end if;
 return null;
end $$;
revoke all on function private.chat_content_check() from public,anon,authenticated,homecircle_api;
create constraint trigger chat_message_content after insert or update on public.household_messages
 deferrable initially deferred for each row execute function private.chat_content_check();
create constraint trigger chat_attachment_content after insert or update or delete on public.message_attachments
 deferrable initially deferred for each row execute function private.chat_content_check();

create function private.chat_event() returns trigger
language plpgsql security definer set search_path='' as $$
declare h uuid; mid uuid; rev bigint; event_kind text;
begin
 h:=coalesce(new.household_id,old.household_id);
 if TG_TABLE_NAME='household_messages' then
   mid:=new.id; rev:=new.revision;
   event_kind:=case when TG_OP='INSERT' then 'message_created' when new.deleted_at is not null then 'message_deleted' else 'message_edited' end;
 else
   mid:=coalesce(new.message_id,old.message_id);
   select revision into rev from public.household_messages where household_id=h and id=mid;
   if not found then return null; end if;
   event_kind:=case when TG_TABLE_NAME='message_reactions' then 'reaction_changed'
     when TG_TABLE_NAME='chat_task_conversions' then 'task_linked' else 'attachment_changed' end;
 end if;
 insert into public.chat_events(household_id,message_id,actor_id,kind,revision) values(h,mid,private.current_actor(),event_kind,rev);
 return null;
end $$;
revoke all on function private.chat_event() from public,anon,authenticated,homecircle_api;
create trigger chat_message_event after insert or update on public.household_messages for each row execute function private.chat_event();
create trigger chat_reaction_event after insert or delete on public.message_reactions for each row execute function private.chat_event();
create trigger chat_attachment_event after insert or update on public.message_attachments for each row execute function private.chat_event();
create trigger chat_conversion_event after insert on public.chat_task_conversions for each row execute function private.chat_event();

-- Receive-only authorization. No authenticated INSERT policy allows client broadcast.
create function private.chat_topic_allowed(topic text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.household_members m where m.user_id=auth.uid()
 and $1='chat:'||m.household_id::text||':'||m.user_id::text);
$$;
revoke all on function private.chat_topic_allowed(text) from public,anon;
grant execute on function private.chat_topic_allowed(text) to authenticated;
create policy chat_receive on realtime.messages for select to authenticated
 using(extension='broadcast' and topic=realtime.topic() and private.chat_topic_allowed(realtime.topic()));
-- Existing policies for other features cannot broaden the chat namespace.
create policy chat_receive_boundary on realtime.messages as restrictive for select to authenticated
 using(topic not like 'chat:%' or (topic=realtime.topic() and private.chat_topic_allowed(topic)));
create policy chat_publish_boundary on realtime.messages as restrictive for insert to authenticated
 with check(topic not like 'chat:%');

-- Owner-only durable publisher. Current members get separate private topics.
-- The queue acknowledgement check also catches realtime.send's missing-partition warning.
create function public.dispatch_chat_outbox(batch_size integer default 100) returns integer
language plpgsql security definer set search_path='' as $$
declare e public.chat_events; recipient uuid; destination text; complete boolean; delivered integer:=0;
begin
 for e in select * from public.chat_events where published_at is null order by sequence
   limit least(greatest(batch_size,1),500) for update skip locked loop
   complete:=true;
   perform 1 from public.households where id=e.household_id for share;
   for recipient in select user_id from public.household_members where household_id=e.household_id loop
     destination:='chat:'||e.household_id::text||':'||recipient::text;
     begin
       perform realtime.send(jsonb_build_object('event_id',e.event_id,'household_id',e.household_id,
         'message_id',e.message_id,'sequence',e.sequence,'kind',e.kind,'revision',e.revision), 'chat_changed',destination,true);
       if not exists(select 1 from realtime.messages r where r.topic=destination and
         (r.payload->>'event_id'=e.event_id::text or r.payload->'payload'->>'event_id'=e.event_id::text)) then complete:=false; end if;
     exception when others then complete:=false;
     end;
   end loop;
   if complete then update public.chat_events set published_at=clock_timestamp() where sequence=e.sequence; delivered:=delivered+1; end if;
 end loop;
 return delivered;
end $$;
revoke all on function public.dispatch_chat_outbox(integer) from public,anon,authenticated,homecircle_api;
create function private.chat_publish() returns trigger language plpgsql security definer set search_path='' as $$
begin perform public.dispatch_chat_outbox(20); return null; end $$;
revoke all on function private.chat_publish() from public,anon,authenticated,homecircle_api;
create trigger chat_outbox_publish after insert on public.chat_events for each statement execute function private.chat_publish();

create table private.chat_rate_limits (
 household_id uuid not null references public.households(id) on delete cascade, actor_id uuid not null,
 action text not null, window_start timestamptz not null, count integer not null,
 primary key(household_id,actor_id,action)
);
alter table private.chat_rate_limits enable row level security;
revoke all on private.chat_rate_limits from public,anon,authenticated,homecircle_api;
grant select,insert,update on private.chat_rate_limits to homecircle_api;
create policy chat_rates on private.chat_rate_limits for all to homecircle_api
 using(actor_id=private.current_actor() and private.is_member(household_id))
 with check(actor_id=private.current_actor() and private.is_member(household_id));

alter table public.household_messages enable row level security;
alter table public.message_reactions enable row level security;
alter table public.message_attachments enable row level security;
alter table public.chat_events enable row level security;
alter table public.chat_task_conversions enable row level security;
alter table private.chat_uploads enable row level security;
revoke all on public.household_messages,public.message_reactions,public.message_attachments,public.chat_events,
 public.chat_task_conversions,private.chat_uploads from public,anon,authenticated,homecircle_api;
grant select,insert on public.household_messages,public.message_reactions,public.message_attachments,public.chat_task_conversions to homecircle_api;
grant select on public.chat_events to homecircle_api;
grant update(body,edited_at,deleted_at) on public.household_messages to homecircle_api;
grant update(removed_at) on public.message_attachments to homecircle_api;
grant delete on public.message_reactions to homecircle_api;
grant select,insert on private.chat_uploads to homecircle_api;
grant update(finalized,expires_at,abandoned) on private.chat_uploads to homecircle_api;
create policy chat_messages_read on public.household_messages for select to homecircle_api using(private.is_member(household_id));
create policy chat_messages_insert on public.household_messages for insert to homecircle_api
 with check(private.is_member(household_id) and sender_user_id=private.current_actor() and message_type<>'system');
create policy chat_messages_update on public.household_messages for update to homecircle_api
 using(private.is_member(household_id) and sender_user_id=private.current_actor())
 with check(private.is_member(household_id) and sender_user_id=private.current_actor());
create policy chat_reactions_read on public.message_reactions for select to homecircle_api using(private.is_member(household_id));
create policy chat_reactions_insert on public.message_reactions for insert to homecircle_api
 with check(private.is_member(household_id) and user_id=private.current_actor());
create policy chat_reactions_delete on public.message_reactions for delete to homecircle_api using(private.is_member(household_id) and user_id=private.current_actor());
create policy chat_attachments_read on public.message_attachments for select to homecircle_api using(private.is_member(household_id));
create policy chat_attachments_insert on public.message_attachments for insert to homecircle_api
 with check(private.is_member(household_id) and uploaded_by=private.current_actor());
create policy chat_attachments_update on public.message_attachments for update to homecircle_api
 using(private.is_member(household_id) and uploaded_by=private.current_actor()) with check(private.is_member(household_id) and uploaded_by=private.current_actor());
create policy chat_conversions on public.chat_task_conversions for all to homecircle_api
 using(private.is_member(household_id)) with check(private.is_member(household_id) and actor_id=private.current_actor());
create policy chat_events_read on public.chat_events for select to homecircle_api using(private.is_member(household_id));
create policy chat_uploads on private.chat_uploads for all to homecircle_api
 using(actor_id=private.current_actor() and private.is_member(household_id)) with check(actor_id=private.current_actor() and private.is_member(household_id));

create function private.chat_photo_read(path text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.message_attachments a join public.household_messages m
 on m.id=a.message_id and m.household_id=a.household_id where a.storage_path=$1
 and a.removed_at is null and m.deleted_at is null and private.is_member(a.household_id));
$$;
create function private.chat_upload_allowed(path text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.chat_uploads u where u.storage_path=$1 and u.actor_id=auth.uid()
 and u.expires_at>clock_timestamp() and not u.finalized and private.is_member(u.household_id));
$$;
create function private.chat_photo_cleanup(path text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.chat_uploads u where u.storage_path=$1 and u.actor_id=auth.uid()
 and u.finalized and private.is_member(u.household_id)) and not exists(select 1 from public.message_attachments a
 join public.household_messages m on m.household_id=a.household_id and m.id=a.message_id
 where a.storage_path=$1 and a.removed_at is null and m.deleted_at is null);
$$;
revoke all on function private.chat_photo_read(text),private.chat_upload_allowed(text),private.chat_photo_cleanup(text) from public,anon;
grant execute on function private.chat_photo_read(text),private.chat_upload_allowed(text),private.chat_photo_cleanup(text) to authenticated;
drop policy homecircle_private_object_read on storage.objects;
create policy homecircle_private_object_read on storage.objects for select to authenticated
 using(bucket_id='household-images' and private.is_member(private.object_household(name)));
create policy chat_photo_insert on storage.objects for insert to authenticated
 with check(bucket_id='chat-attachments' and private.chat_upload_allowed(name));
create policy chat_photo_select on storage.objects for select to authenticated
 using(bucket_id='chat-attachments' and (private.chat_photo_read(name) or private.chat_upload_allowed(name) or private.chat_photo_cleanup(name)));
create policy chat_photo_delete on storage.objects for delete to authenticated
 using(bucket_id='chat-attachments' and private.chat_photo_cleanup(name));
