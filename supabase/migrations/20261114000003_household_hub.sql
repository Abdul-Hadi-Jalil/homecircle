-- Requires M0-M5. Apply first to a separate disposable Supabase project.
-- A restricted, separately provisioned login runs the notification worker.
do $$ begin
 if not exists(select 1 from pg_roles where rolname='homecircle_worker') then
   create role homecircle_worker nologin nosuperuser nocreatedb nocreaterole nobypassrls;
 end if;
end $$;
grant usage on schema public,private to homecircle_worker;

alter table public.households add column time_zone text not null default 'UTC';
grant update(time_zone) on public.households to homecircle_api;
create function private.validate_household_zone() returns trigger
language plpgsql set search_path='' as $$ begin
 if not exists(select 1 from pg_timezone_names where name=new.time_zone) then
   raise check_violation using message='Unknown household time zone';
 end if;
 return new;
end $$;
revoke all on function private.validate_household_zone() from public,anon,authenticated,homecircle_api;
create trigger household_zone before insert or update of time_zone on public.households
 for each row execute function private.validate_household_zone();

create table public.household_activity_events (
 id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
 source_kind text not null, source_event_id uuid not null, source_revision bigint,
 actor_user_id uuid, actor_display_name text,
 event_type text not null, category text not null check(category in ('inventory','shopping','tasks','repairs','members')),
 entity_type text not null check(entity_type in ('inventory','task','shopping','household')),
 entity_id uuid not null, title text not null, metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default clock_timestamp(), unique(source_kind,source_event_id)
);
create index family_activity_page on public.household_activity_events(household_id,created_at desc,id desc);
create index family_activity_category on public.household_activity_events(household_id,category,created_at desc,id desc);
create unique index family_activity_revision on public.household_activity_events(household_id,entity_type,entity_id,source_revision) where source_revision is not null;
alter table public.household_activity_events enable row level security;
revoke all on public.household_activity_events from public,anon,authenticated,homecircle_api;
grant select on public.household_activity_events to homecircle_api;
create policy family_activity_read on public.household_activity_events for select to homecircle_api using(private.is_member(household_id));

-- A projection of persisted feature activity, not a second independently written audit.
create function private.project_family_activity() returns trigger
language plpgsql security definer set search_path='' as $$
declare entity uuid; label text; category_name text; entity_name text; source_name text; version bigint;
begin
 if TG_TABLE_NAME='inventory_activity' then
   entity:=new.inventory_item_id; category_name:='inventory'; entity_name:='inventory'; source_name:='inventory';
   select name,revision into label,version from public.inventory_items where id=entity and household_id=new.household_id;
 else
   entity:=new.task_id; source_name:='task';
   select title,case task_type when 'shopping' then 'shopping' when 'repair' then 'repairs' else 'tasks' end,
     case task_type when 'shopping' then 'shopping' else 'task' end,revision
   into label,category_name,entity_name,version from public.household_tasks where id=entity and household_id=new.household_id;
 end if;
 insert into public.household_activity_events(household_id,source_kind,source_event_id,actor_user_id,
   actor_display_name,event_type,category,entity_type,entity_id,title,created_at,source_revision)
 select new.household_id,source_name,new.id,new.actor_user_id,
   (select display_name from public.profiles where id=new.actor_user_id),new.action,category_name,entity_name,entity,
   coalesce(label,'Unavailable record'),new.created_at,version
 on conflict do nothing;
 return new;
end $$;
revoke all on function private.project_family_activity() from public,anon,authenticated,homecircle_api;
create trigger inventory_family_activity after insert on public.inventory_activity
 for each row execute function private.project_family_activity();
create trigger task_family_activity after insert on public.task_activity
 for each row execute function private.project_family_activity();

-- Historical actions/times are retained; backfilled labels use the current record name.
-- Install notification triggers AFTER backfill so deployment never sends historical alerts.
insert into public.household_activity_events(household_id,source_kind,source_event_id,actor_user_id,
 actor_display_name,event_type,category,entity_type,entity_id,title,created_at,metadata)
select a.household_id,'inventory',a.id,a.actor_user_id,p.display_name,a.action,'inventory','inventory',i.id,i.name,a.created_at,
 '{"backfilled":true,"label_policy":"current_record_name"}'::jsonb
from public.inventory_activity a join public.inventory_items i on i.id=a.inventory_item_id and i.household_id=a.household_id
left join public.profiles p on p.id=a.actor_user_id;
insert into public.household_activity_events(household_id,source_kind,source_event_id,actor_user_id,
 actor_display_name,event_type,category,entity_type,entity_id,title,created_at,metadata)
select a.household_id,'task',a.id,a.actor_user_id,p.display_name,a.action,
 case t.task_type when 'repair' then 'repairs' when 'shopping' then 'shopping' else 'tasks' end,
 case t.task_type when 'shopping' then 'shopping' else 'task' end,t.id,t.title,a.created_at,
 '{"backfilled":true,"label_policy":"current_record_name"}'::jsonb
from public.task_activity a join public.household_tasks t on t.id=a.task_id and t.household_id=a.household_id
left join public.profiles p on p.id=a.actor_user_id;

create table public.notification_preferences (
 user_id uuid not null references public.profiles(id) on delete cascade,
 household_id uuid not null references public.households(id) on delete cascade,
 tasks_enabled boolean not null default true, shopping_enabled boolean not null default true,
 inventory_enabled boolean not null default true, chat_enabled boolean not null default true,
 mentions_enabled boolean not null default true, push_enabled boolean not null default true,
 updated_at timestamptz not null default clock_timestamp(), primary key(user_id,household_id)
);
create table public.user_notifications (
 id uuid primary key default gen_random_uuid(), recipient_user_id uuid not null references public.profiles(id) on delete cascade,
 household_id uuid not null references public.households(id) on delete cascade,
 event_type text not null check(event_type in ('task_assigned','task_reassigned','task_completed','urgent_request',
 'shopping_updated','low_stock','inventory_condition_changed','chat_message','chat_mention','membership_updated')),
 title text not null, body text not null, related_entity_type text not null,
 related_entity_id uuid not null, source_event_id uuid not null,
 created_at timestamptz not null default clock_timestamp(), read_at timestamptz, dismissed_at timestamptz,
 unique(household_id,recipient_user_id,source_event_id)
);
create index notifications_page on public.user_notifications(recipient_user_id,household_id,created_at desc,id desc);
create index notifications_unread on public.user_notifications(recipient_user_id,household_id) where read_at is null and dismissed_at is null;
create table public.user_device_tokens (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 token text not null check(length(token) between 20 and 4096),
 token_hash bytea not null check(octet_length(token_hash)=32),
 platform text not null check(platform in ('android','ios')), device_identifier uuid not null,
 created_at timestamptz not null default clock_timestamp(), updated_at timestamptz not null default clock_timestamp(),
 last_seen_at timestamptz not null default clock_timestamp(), revoked_at timestamptz,
 unique(user_id,token_hash), unique(id,user_id)
);
create unique index devices_active_token on public.user_device_tokens(token_hash) where revoked_at is null;
create unique index devices_active_installation on public.user_device_tokens(user_id,device_identifier) where revoked_at is null;
create table private.device_revocations (
 user_id uuid not null references public.profiles(id) on delete cascade,
 device_identifier uuid not null, created_at timestamptz not null default clock_timestamp(),
 primary key(user_id,device_identifier)
);
alter table private.device_revocations enable row level security;
revoke all on private.device_revocations from public,anon,authenticated,homecircle_api,homecircle_worker;
create table private.notification_push_jobs (
 id uuid primary key default gen_random_uuid(), notification_id uuid not null references public.user_notifications(id) on delete cascade,
 device_token_id uuid not null references public.user_device_tokens(id) on delete cascade,
 state text not null default 'pending' check(state in ('pending','processing','sent','permanent','suppressed')),
 attempts integer not null default 0, next_retry_at timestamptz not null default clock_timestamp(),
 lease_id uuid, lease_until timestamptz, last_error_category text,
 created_at timestamptz not null default clock_timestamp(), delivered_at timestamptz,
 unique(notification_id,device_token_id)
);
create index notification_jobs_ready on private.notification_push_jobs(state,next_retry_at,lease_until);
alter table public.notification_preferences enable row level security;
alter table public.user_notifications enable row level security;
alter table public.user_device_tokens enable row level security;
alter table private.notification_push_jobs enable row level security;
revoke all on public.notification_preferences,public.user_notifications,public.user_device_tokens,private.notification_push_jobs
 from public,anon,authenticated,homecircle_api,homecircle_worker;
grant select,insert on public.notification_preferences to homecircle_api;
grant update(tasks_enabled,shopping_enabled,inventory_enabled,chat_enabled,mentions_enabled,push_enabled,updated_at)
 on public.notification_preferences to homecircle_api;
grant select on public.user_notifications to homecircle_api;
grant update(read_at,dismissed_at) on public.user_notifications to homecircle_api;
create policy notification_preferences_own on public.notification_preferences for all to homecircle_api
 using(user_id=private.current_actor() and private.is_member(household_id))
 with check(user_id=private.current_actor() and private.is_member(household_id));
create policy notification_read_own on public.user_notifications for select to homecircle_api
 using(recipient_user_id=private.current_actor() and private.is_member(household_id));
create policy notification_update_own on public.user_notifications for update to homecircle_api
 using(recipient_user_id=private.current_actor() and private.is_member(household_id))
 with check(recipient_user_id=private.current_actor() and private.is_member(household_id));

create function private.notification_enabled(uid uuid,home uuid,kind text,push boolean default false) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.household_members where household_id=home and user_id=uid)
 and coalesce((select (not push or p.push_enabled) and case
 when kind in ('task_assigned','task_reassigned','task_completed','urgent_request') then p.tasks_enabled
 when kind='shopping_updated' then p.shopping_enabled
 when kind in ('low_stock','inventory_condition_changed') then p.inventory_enabled
 when kind='chat_message' then p.chat_enabled when kind='chat_mention' then p.mentions_enabled else true end
 from public.notification_preferences p where p.user_id=uid and p.household_id=home),true);
$$;
revoke all on function private.notification_enabled(uuid,uuid,text,boolean) from public,anon,authenticated,homecircle_api,homecircle_worker;
create function private.queue_notification(home uuid,recipient uuid,actor uuid,source uuid,kind text,entity text,target uuid,heading text,summary text)
returns void language plpgsql security definer set search_path='' as $$
declare nid uuid;
begin
 if recipient is null or recipient is not distinct from actor or not private.notification_enabled(recipient,home,kind) then return; end if;
 insert into public.user_notifications(household_id,recipient_user_id,source_event_id,event_type,title,body,related_entity_type,related_entity_id)
 values(home,recipient,source,kind,left(heading,160),left(summary,300),entity,target)
 on conflict(household_id,recipient_user_id,source_event_id) do nothing returning id into nid;
 if nid is not null and private.notification_enabled(recipient,home,kind,true) then
   insert into private.notification_push_jobs(notification_id,device_token_id)
   select nid,d.id from public.user_device_tokens d where d.user_id=recipient and d.revoked_at is null
   on conflict(notification_id,device_token_id) do nothing;
 end if;
end $$;
revoke all on function private.queue_notification(uuid,uuid,uuid,uuid,text,text,uuid,text,text) from public,anon,authenticated,homecircle_api,homecircle_worker;

-- Notifications use trusted state plus the immutable source change, never read requests.
create function private.family_event_notifications() returns trigger
language plpgsql security definer set search_path='' as $$
declare t public.household_tasks; i public.inventory_items; delta jsonb; recipient uuid; kind text;
 old_quantity numeric; old_min numeric; old_type text; before_rank integer; after_rank integer;
begin
 if new.source_kind='task' then
   select * into t from public.household_tasks where id=new.entity_id and household_id=new.household_id;
   select changes into delta from public.task_activity where id=new.source_event_id;
   if t.deleted_at is not null then return new; end if;
   for recipient in select user_id from public.household_members where household_id=new.household_id loop
     kind:=null;
     if t.assigned_to=recipient and (new.event_type='created' or
       (delta ? 'assigned_to' and delta->'assigned_to'->>'after' is not null)) then
       kind:=case when delta->'assigned_to'->>'before' is not null then 'task_reassigned' else 'task_assigned' end;
     elsif t.task_type='shopping' and new.event_type in ('created','completed','reopened','cancelled','updated') then kind:='shopping_updated';
     elsif new.event_type='completed' and recipient in (t.created_by,t.assigned_to) then kind:='task_completed';
     elsif t.task_type<>'shopping' and t.priority='urgent' and t.status in ('open','in_progress','blocked')
       and (new.event_type='created' or delta ? 'priority') then kind:='urgent_request';
     end if;
     if kind is not null then perform private.queue_notification(new.household_id,recipient,new.actor_user_id,new.id,kind,new.entity_type,t.id,t.title,'A household request has an update.'); end if;
   end loop;
 elsif new.source_kind='inventory' then
   select * into i from public.inventory_items where id=new.entity_id and household_id=new.household_id;
   select changes into delta from public.inventory_activity where id=new.source_event_id;
   if i.deleted_at is not null then return new; end if;
   kind:=null;
   if i.item_type='consumable' then
     old_quantity:=coalesce((delta->'quantity'->>'before')::numeric,i.quantity);
     old_min:=case when delta ? 'minimum_quantity' then (delta->'minimum_quantity'->>'before')::numeric else i.minimum_quantity end;
     old_type:=coalesce(delta->'item_type'->>'before',i.item_type);
     before_rank:=case when old_type<>'consumable' then 0 when old_quantity=0 then 2 when old_quantity<=old_min then 1 else 0 end;
     after_rank:=case when i.quantity=0 then 2 when i.quantity<=i.minimum_quantity then 1 else 0 end;
     if after_rank>before_rank or (new.event_type='created' and after_rank>0) then kind:='low_stock'; end if;
   elsif i.condition in ('broken','needs_repair') and delta ? 'condition'
     and delta->'condition'->>'before' is distinct from i.condition then kind:='inventory_condition_changed'; end if;
   if kind is not null then
     for recipient in select user_id from public.household_members where household_id=new.household_id loop
       perform private.queue_notification(new.household_id,recipient,new.actor_user_id,new.id,kind,'inventory',i.id,i.name,'An inventory item needs attention.');
     end loop;
   end if;
 elsif new.category='members' then
   for recipient in select user_id from public.household_members where household_id=new.household_id loop
     perform private.queue_notification(new.household_id,recipient,new.actor_user_id,new.id,'membership_updated','household',new.household_id,'Household membership updated','Open HomeCircle to review household members.');
   end loop;
 end if;
 return new;
end $$;
revoke all on function private.family_event_notifications() from public,anon,authenticated,homecircle_api,homecircle_worker;
create trigger family_event_notifications after insert on public.household_activity_events
 for each row execute function private.family_event_notifications();

create function private.member_family_activity() returns trigger
language plpgsql security definer set search_path='' as $$
declare home uuid; subject uuid; kind text;
begin
 home:=coalesce(new.household_id,old.household_id); subject:=coalesce(new.user_id,old.user_id);
 if not exists(select 1 from public.households where id=home) then return null; end if;
 if TG_OP='UPDATE' and new.role is not distinct from old.role then return new; end if;
 kind:=case when TG_OP='INSERT' and private.current_actor()=subject then 'member_joined'
 when TG_OP='INSERT' then 'member_added' when TG_OP='DELETE' and private.current_actor()=subject then 'member_left'
 when TG_OP='DELETE' then 'member_removed' else 'member_role_changed' end;
 insert into public.household_activity_events(household_id,source_kind,source_event_id,actor_user_id,actor_display_name,event_type,category,entity_type,entity_id,title)
 values(home,'member',gen_random_uuid(),private.current_actor(),
 (select display_name from public.profiles where id=private.current_actor()),kind,'members','household',home,
 case when kind in ('member_joined','member_left') then (select name from public.households where id=home)
 else coalesce((select display_name from public.profiles where id=subject),'Former member') end);
 if TG_OP='DELETE' then
   delete from public.notification_preferences where user_id=subject and household_id=home;
   -- Remove inaccessible history, including pending jobs via FK cascade.
   delete from public.user_notifications where recipient_user_id=subject and household_id=home;
 end if;
 return null;
end $$;
revoke all on function private.member_family_activity() from public,anon,authenticated,homecircle_api,homecircle_worker;
create trigger member_family_activity after insert or update or delete on public.household_members
 for each row execute function private.member_family_activity();

alter table public.household_messages add column mentioned_user_ids uuid[] not null default '{}';
create function private.validate_chat_mentions() returns trigger
language plpgsql security definer set search_path='' as $$ begin
 if TG_OP='UPDATE' and new.mentioned_user_ids is distinct from old.mentioned_user_ids then
   raise check_violation using message='Mentions are immutable';
 end if;
 if TG_OP='INSERT' and (cardinality(new.mentioned_user_ids)>20 or exists(
   select 1 from unnest(new.mentioned_user_ids) as target(member_id) where not exists(
    select 1 from public.household_members m where m.household_id=new.household_id and m.user_id=target.member_id))) then
   raise check_violation using message='Mention is not a current member';
 end if;
 return new;
end $$;
revoke all on function private.validate_chat_mentions() from public,anon,authenticated,homecircle_api,homecircle_worker;
create trigger chat_mentions_validate before insert or update on public.household_messages
 for each row execute function private.validate_chat_mentions();
create function private.chat_notifications() returns trigger
language plpgsql security definer set search_path='' as $$
declare m public.household_messages; recipient uuid; kind text;
begin
 if new.kind<>'message_created' then return new; end if;
 select * into m from public.household_messages where id=new.message_id and household_id=new.household_id;
 for recipient in select user_id from public.household_members where household_id=m.household_id loop
   kind:=case when recipient=any(m.mentioned_user_ids) then 'chat_mention' else 'chat_message' end;
   perform private.queue_notification(m.household_id,recipient,m.sender_user_id,new.event_id,kind,'chat',m.id,
     'Family chat','Open HomeCircle to view a family message.');
 end loop;
 return new;
end $$;
revoke all on function private.chat_notifications() from public,anon,authenticated,homecircle_api,homecircle_worker;
create trigger chat_notifications after insert on public.chat_events for each row execute function private.chat_notifications();

-- Token ownership is never exposed; possession plus verified identity permits installation handoff.
create function public.register_fcm_device(value text,installation uuid,device_platform text) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.current_actor(); result uuid;
begin
 if actor is null or length(value) not between 20 and 4096 or device_platform not in ('android','ios') then
   raise check_violation using message='Invalid device registration'; end if;
 perform pg_advisory_xact_lock(hashtextextended(value,6));
 perform pg_advisory_xact_lock(hashtextextended(actor::text,7));
 if exists(select 1 from private.device_revocations where user_id=actor and device_identifier=installation) then
   raise check_violation using message='This installation session was revoked'; end if;
 if (select count(*) from public.user_device_tokens where user_id=actor and revoked_at is null)>=20
 and not exists(select 1 from public.user_device_tokens where user_id=actor and device_identifier=installation and revoked_at is null) then
   raise check_violation using message='Device limit reached'; end if;
 update public.user_device_tokens set revoked_at=clock_timestamp() where revoked_at is null and
   ((token_hash=sha256(convert_to(value,'UTF8')) and user_id<>actor) or (user_id=actor and device_identifier=installation));
 insert into public.user_device_tokens(user_id,token,token_hash,platform,device_identifier) values(actor,value,sha256(convert_to(value,'UTF8')),device_platform,installation)
 on conflict(user_id,token_hash) do update set platform=excluded.platform,device_identifier=excluded.device_identifier,
 updated_at=clock_timestamp(),last_seen_at=clock_timestamp(),revoked_at=null returning id into result;
 return result;
end $$;
create function public.revoke_fcm_device(installation uuid) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.current_actor();
begin
 if actor is null then raise check_violation using message='Authenticated actor required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text,7));
 insert into private.device_revocations(user_id,device_identifier) values(actor,installation) on conflict do nothing;
 update public.user_device_tokens set revoked_at=clock_timestamp() where user_id=actor and device_identifier=installation;
end;
$$;
revoke all on function public.register_fcm_device(text,uuid,text),public.revoke_fcm_device(uuid) from public,anon,authenticated,homecircle_worker;
grant execute on function public.register_fcm_device(text,uuid,text),public.revoke_fcm_device(uuid) to homecircle_api;

-- Claim leases commit before FCM I/O. Expired leases are recoverable; stale acknowledgements are rejected.
create function public.claim_notification_jobs(batch_size integer default 20) returns table(job_id uuid,lease uuid)
language plpgsql security definer set search_path='' as $$ begin
 return query with candidates as (
 select j.id from private.notification_push_jobs j where j.attempts<8 and
 ((j.state='pending' and j.next_retry_at<=clock_timestamp()) or (j.state='processing' and j.lease_until<clock_timestamp()))
 order by j.next_retry_at,j.id limit least(greatest(batch_size,1),100) for update skip locked
 ) update private.notification_push_jobs j set state='processing',attempts=j.attempts+1,
 lease_id=gen_random_uuid(),lease_until=clock_timestamp()+interval '2 minutes'
 from candidates c where j.id=c.id returning j.id,j.lease_id;
 update private.notification_push_jobs set state='permanent',last_error_category='attempts_exhausted'
 where attempts>=8 and ((state='processing' and lease_until<clock_timestamp()) or state='pending');
end $$;
create function public.authorize_notification_job(job uuid,claim uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j private.notification_push_jobs; n public.user_notifications; d public.user_device_tokens;
begin
 select * into j from private.notification_push_jobs where id=job and lease_id=claim and state='processing' and lease_until>clock_timestamp() for update;
 if not found then return null; end if;
 select * into n from public.user_notifications where id=j.notification_id;
 select * into d from public.user_device_tokens where id=j.device_token_id;
 if d.revoked_at is not null or d.user_id is distinct from n.recipient_user_id or n.dismissed_at is not null or n.read_at is not null
   or not private.notification_enabled(n.recipient_user_id,n.household_id,n.event_type,true) then
   update private.notification_push_jobs set state='suppressed',lease_until=null where id=job; return null;
 end if;
 return jsonb_build_object('token',d.token,'notification_id',n.id,'household_id',n.household_id,
   'event_type',n.event_type,'attempts',j.attempts);
end $$;
create function public.finish_notification_job(job uuid,claim uuid,outcome text,error_category text default null) returns boolean
language plpgsql security definer set search_path='' as $$
declare j private.notification_push_jobs;
begin
 select * into j from private.notification_push_jobs where id=job and lease_id=claim and state='processing'
   and lease_until>clock_timestamp() for update;
 if not found then return false; end if;
 if outcome not in ('sent','retry','invalid_token','permanent') then raise check_violation using message='Invalid delivery outcome'; end if;
 if outcome='invalid_token' then update public.user_device_tokens set revoked_at=clock_timestamp() where id=j.device_token_id; end if;
 update private.notification_push_jobs set state=case when outcome='sent' then 'sent'
 when outcome='retry' and attempts<8 then 'pending' else 'permanent' end,
 next_retry_at=clock_timestamp()+make_interval(secs=>least(3600,30*power(2,least(attempts-1,7)))::integer),
 last_error_category=left(error_category,80),lease_until=null,
 delivered_at=case when outcome='sent' then clock_timestamp() else null end where id=job;
 return true;
end $$;
revoke all on function public.claim_notification_jobs(integer),public.authorize_notification_job(uuid,uuid),public.finish_notification_job(uuid,uuid,text,text)
 from public,anon,authenticated,homecircle_api;
grant execute on function public.claim_notification_jobs(integer),public.authorize_notification_job(uuid,uuid),public.finish_notification_job(uuid,uuid,text,text)
 to homecircle_worker;

-- Raw private events need no new client publication. M6 uses pull/resume/periodic refresh
-- until a dedicated securely authorized household invalidation transport is accepted.
