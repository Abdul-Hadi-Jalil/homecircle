-- Requires all inventory migrations. No privileged runtime role or public bucket.
create table public.household_tasks (
 id uuid primary key default gen_random_uuid(),
 household_id uuid not null references public.households(id) on delete cascade,
 task_type text not null check(task_type in ('repair','chore','general','shopping')),
 title text not null check(length(btrim(title)) between 1 and 150),
 description text check(length(description)<=8000),
 priority text not null default 'normal' check(priority in ('low','normal','high','urgent')),
 status text not null default 'open' check(status in ('open','in_progress','blocked','completed','cancelled')),
 created_by uuid references public.profiles(id) on delete set null,
 assigned_to uuid, updated_by uuid references public.profiles(id) on delete set null,
 due_date date, location text check(length(location)<=150), linked_inventory_item_id uuid,
 completion_note text check(length(completion_note)<=4000), completed_at timestamptz,
 cancelled_at timestamptz, revision bigint not null default 1 check(revision>0),
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(), deleted_at timestamptz,
 unique(household_id,id),
 foreign key(household_id,assigned_to) references public.household_members(household_id,user_id)
   on delete set null (assigned_to),
 foreign key(household_id,linked_inventory_item_id) references public.inventory_items(household_id,id)
   on delete set null (linked_inventory_item_id),
 check(linked_inventory_item_id is null or task_type='repair'),
 check((status='completed')=(completed_at is not null)),
 check((status='cancelled')=(cancelled_at is not null)),
 check(status='completed' or completion_note is null)
);
create index tasks_active on public.household_tasks(household_id,deleted_at,status,updated_at desc,id);
create index tasks_assignee on public.household_tasks(household_id,assigned_to,due_date);
create index tasks_inventory on public.household_tasks(household_id,linked_inventory_item_id);

create table public.task_comments (
 id uuid primary key default gen_random_uuid(), household_id uuid not null, task_id uuid not null,
 author_user_id uuid references public.profiles(id) on delete set null,
 body text not null check(length(btrim(body)) between 1 and 4000),
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(), deleted_at timestamptz,
 revision bigint not null default 1 check(revision>0), unique(household_id,task_id,id),
 foreign key(household_id,task_id) references public.household_tasks(household_id,id) on delete cascade
);
create index task_comments_page on public.task_comments(household_id,task_id,created_at,id);

create table public.task_attachments (
 id uuid primary key default gen_random_uuid(), household_id uuid not null, task_id uuid not null,
 comment_id uuid, uploaded_by uuid references public.profiles(id) on delete set null,
 storage_path text not null unique, content_type text not null check(content_type='image/jpeg'),
 size_bytes integer not null check(size_bytes between 1 and 5242880),
 created_at timestamptz not null default clock_timestamp(), deleted_at timestamptz,
 foreign key(household_id,task_id) references public.household_tasks(household_id,id) on delete cascade,
 foreign key(household_id,task_id,comment_id) references public.task_comments(household_id,task_id,id),
 check(storage_path=household_id::text || '/' || task_id::text || '/' || id::text || '.jpg')
);
create index task_attachments_task on public.task_attachments(household_id,task_id,created_at,id);

create table public.task_activity (
 id uuid primary key default gen_random_uuid(), household_id uuid not null, task_id uuid not null,
 actor_user_id uuid, action text not null check(action in (
 'created','updated','assigned','claimed','unassigned','priority_changed','status_changed',
 'completed','cancelled','reopened','archived','restored','comment_added','comment_edited',
 'comment_deleted','attachment_added','attachment_removed')),
 changes jsonb not null default '{}'::jsonb, created_at timestamptz not null default clock_timestamp(),
 foreign key(household_id,task_id) references public.household_tasks(household_id,id) on delete cascade
);
create index task_activity_page on public.task_activity(household_id,task_id,created_at desc,id);

create function private.validate_task() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if TG_OP='UPDATE' then
   if new.id<>old.id or new.household_id<>old.household_id or new.created_by is distinct from old.created_by then
     -- FK profile deletion may clear creator attribution; client cannot write it.
     if not(new.created_by is null and old.created_by is not null
       and new.id=old.id and new.household_id=old.household_id) then
       raise check_violation using message='Task ownership is immutable';
     end if;
   end if;
   new.revision:=old.revision+1;
   new.updated_at:=clock_timestamp();
   if old.assigned_to is not null and new.assigned_to is null and not exists(
     select 1 from public.household_members where household_id=new.household_id and user_id=old.assigned_to) then
     new.updated_by:=private.current_actor();
   end if;
 end if;
 if new.linked_inventory_item_id is not null and
   (TG_OP='INSERT' or new.linked_inventory_item_id is distinct from old.linked_inventory_item_id) and
   not exists(select 1 from public.inventory_items i where i.household_id=new.household_id
     and i.id=new.linked_inventory_item_id and i.deleted_at is null) then
   raise check_violation using message='Linked item is not available';
 end if;
 if TG_OP='UPDATE' and new.status<>old.status then
   if old.status in ('completed','cancelled') and new.status<>'open' then
     raise check_violation using message='Reopen before changing a terminal task';
   end if;
 end if;
 return new;
end $$;
revoke all on function private.validate_task() from public,anon,authenticated,homecircle_api;
create trigger task_validate before insert or update on public.household_tasks
 for each row execute function private.validate_task();

-- Membership FK unassignment is trusted and must invalidate task revisions too.
create function private.task_member_removed() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if old.assigned_to is not null and new.assigned_to is null and not exists(
   select 1 from public.household_members where household_id=new.household_id and user_id=old.assigned_to) then
   insert into public.task_activity(household_id,task_id,actor_user_id,action,changes)
   values(new.household_id,new.id,private.current_actor(),'unassigned',
     jsonb_build_object('assigned_to',jsonb_build_object('before',old.assigned_to,'after',null),
       'reason','membership_removed'));
 end if;
 return new;
end $$;
revoke all on function private.task_member_removed() from public,anon,authenticated,homecircle_api;
create trigger task_membership_unassigned after update on public.household_tasks
 for each row execute function private.task_member_removed();

alter table public.household_tasks enable row level security;
alter table public.task_comments enable row level security;
alter table public.task_attachments enable row level security;
alter table public.task_activity enable row level security;
revoke all on public.household_tasks,public.task_comments,public.task_attachments,public.task_activity
 from public,anon,authenticated,homecircle_api;
grant select on public.household_tasks,public.task_comments,public.task_attachments,public.task_activity
 to authenticated,homecircle_api;
grant insert on public.household_tasks,public.task_comments,public.task_attachments,public.task_activity to homecircle_api;
grant update(title,description,task_type,priority,status,assigned_to,updated_by,due_date,location,
 linked_inventory_item_id,completion_note,completed_at,cancelled_at,deleted_at) on public.household_tasks to homecircle_api;
grant update(body,updated_at,deleted_at,revision) on public.task_comments to homecircle_api;
grant update(deleted_at) on public.task_attachments to homecircle_api;

create policy tasks_read on public.household_tasks for select to authenticated,homecircle_api
 using(private.is_member(household_id));
create policy tasks_insert on public.household_tasks for insert to homecircle_api
 with check(private.is_member(household_id) and created_by=private.current_actor() and updated_by=private.current_actor());
create policy tasks_update on public.household_tasks for update to homecircle_api
 using(private.is_member(household_id)) with check(private.is_member(household_id) and updated_by=private.current_actor());
create policy comments_read on public.task_comments for select to authenticated,homecircle_api
 using(private.is_member(household_id));
create policy comments_insert on public.task_comments for insert to homecircle_api
 with check(private.is_member(household_id) and author_user_id=private.current_actor());
create policy comments_update on public.task_comments for update to homecircle_api
 using(private.is_member(household_id) and (author_user_id=private.current_actor() or private.is_admin(household_id)))
 with check(private.is_member(household_id) and (author_user_id=private.current_actor() or private.is_admin(household_id)));
create policy task_attachments_read on public.task_attachments for select to authenticated,homecircle_api
 using(private.is_member(household_id));
create policy task_attachments_insert on public.task_attachments for insert to homecircle_api
 with check(private.is_member(household_id) and uploaded_by=private.current_actor());
create policy task_attachments_remove on public.task_attachments for update to homecircle_api
 using(private.is_member(household_id) and (uploaded_by=private.current_actor() or private.is_admin(household_id)))
 with check(private.is_member(household_id));
create policy task_activity_read on public.task_activity for select to authenticated,homecircle_api
 using(private.is_member(household_id));
create policy task_activity_insert on public.task_activity for insert to homecircle_api
 with check(private.is_member(household_id) and actor_user_id=private.current_actor());

create function public.task_actor_name(target uuid, actor uuid) returns text
language sql stable security definer set search_path='' as $$
 select p.display_name from public.profiles p where p.id=actor and private.is_member(target) and (
   exists(select 1 from public.household_members m where m.household_id=target and m.user_id=actor)
   or exists(select 1 from public.task_activity a where a.household_id=target and a.actor_user_id=actor));
$$;
revoke all on function public.task_actor_name(uuid,uuid) from public,anon,authenticated;
grant execute on function public.task_actor_name(uuid,uuid) to homecircle_api;

create table private.task_uploads (
 path text primary key, household_id uuid not null references public.households(id) on delete cascade,
 actor_id uuid not null, expires_at timestamptz not null default(clock_timestamp()+interval '60 seconds'),
 finalized boolean not null default false
);
alter table private.task_uploads enable row level security;
revoke all on private.task_uploads from public,anon,authenticated,homecircle_api;
grant select,insert,delete on private.task_uploads to homecircle_api;
grant update(finalized) on private.task_uploads to homecircle_api;
create policy task_uploads_read on private.task_uploads for select to homecircle_api using(actor_id=private.current_actor());
create policy task_uploads_insert on private.task_uploads for insert to homecircle_api
 with check(actor_id=private.current_actor() and private.is_member(household_id) and path like household_id::text || '/%');
create policy task_uploads_update on private.task_uploads for update to homecircle_api
 using(actor_id=private.current_actor()) with check(actor_id=private.current_actor());
create policy task_uploads_delete on private.task_uploads for delete to homecircle_api using(actor_id=private.current_actor());

create function private.task_upload_allowed(path text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.task_uploads u where u.path=$1 and u.actor_id=auth.uid()
 and u.expires_at>clock_timestamp() and private.is_member(u.household_id));
$$;
create function private.task_photo_read(path text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.task_attachments a join public.household_tasks t
 on t.household_id=a.household_id and t.id=a.task_id where a.storage_path=$1
 and a.deleted_at is null and t.deleted_at is null and private.is_member(a.household_id)
 and (a.comment_id is null or exists(select 1 from public.task_comments c where c.id=a.comment_id
 and c.household_id=a.household_id and c.task_id=a.task_id and c.deleted_at is null)));
$$;
create function private.task_photo_cleanup(path text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.task_uploads u where u.path=$1 and u.finalized
   and private.is_member(u.household_id) and (u.actor_id=auth.uid() or private.is_admin(u.household_id)))
 and not exists(select 1 from public.task_attachments a where a.storage_path=$1 and a.deleted_at is null
   and (a.comment_id is null or exists(select 1 from public.task_comments c where c.id=a.comment_id
     and c.household_id=a.household_id and c.task_id=a.task_id and c.deleted_at is null)));
$$;
revoke all on function private.task_upload_allowed(text),private.task_photo_read(text),private.task_photo_cleanup(text) from public,anon;
grant execute on function private.task_upload_allowed(text),private.task_photo_read(text),private.task_photo_cleanup(text) to authenticated;
-- Remove broad foundation read access to repair files; keep other reserved buckets unchanged.
drop policy homecircle_private_object_read on storage.objects;
create policy homecircle_private_object_read on storage.objects for select to authenticated
 using(bucket_id in ('household-images','chat-attachments') and private.is_member(private.object_household(name)));
create policy task_photo_insert on storage.objects for insert to authenticated
 with check(bucket_id='repair-attachments' and private.task_upload_allowed(name));
create policy task_photo_select on storage.objects for select to authenticated
 using(bucket_id='repair-attachments' and (private.task_photo_read(name) or private.task_upload_allowed(name) or private.task_photo_cleanup(name)));
create policy task_photo_delete on storage.objects for delete to authenticated
 using(bucket_id='repair-attachments' and private.task_photo_cleanup(name));
