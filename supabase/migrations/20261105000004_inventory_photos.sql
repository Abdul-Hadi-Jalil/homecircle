create table private.inventory_uploads (
 path text primary key, household_id uuid not null references public.households(id) on delete cascade,
 actor_id uuid not null, expires_at timestamptz not null default (clock_timestamp()+interval '60 seconds')
);
alter table private.inventory_uploads enable row level security;
revoke all on private.inventory_uploads from public,anon,authenticated,homecircle_api;
grant insert,delete on private.inventory_uploads to homecircle_api;
create policy inventory_upload_insert on private.inventory_uploads for insert to homecircle_api
 with check(actor_id=private.current_actor() and private.is_member(household_id)
 and path like household_id::text || '/%');
create policy inventory_upload_delete on private.inventory_uploads for delete to homecircle_api
 using(actor_id=private.current_actor());
grant select on private.inventory_uploads to homecircle_api;
create policy inventory_upload_select on private.inventory_uploads for select to homecircle_api using(actor_id=private.current_actor());

create function private.inventory_upload_allowed(object_name text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.inventory_uploads u where u.path=object_name
 and u.actor_id=auth.uid() and u.expires_at>clock_timestamp() and private.is_member(u.household_id));
$$;
create function private.inventory_photo_read(object_name text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.inventory_items i where i.photo_path=object_name
 and i.deleted_at is null and private.is_member(i.household_id));
$$;
revoke all on function private.inventory_upload_allowed(text),private.inventory_photo_read(text) from public,anon;
grant execute on function private.inventory_upload_allowed(text),private.inventory_photo_read(text) to authenticated;
create policy inventory_photo_insert on storage.objects for insert to authenticated
 with check(bucket_id='inventory-photos' and private.inventory_upload_allowed(name));
create policy inventory_photo_select on storage.objects for select to authenticated
 using(bucket_id='inventory-photos' and private.inventory_photo_read(name));
-- No upsert, overwrite, or client delete permission. Old photos and archived
-- history are retained until an explicit retention job; no destructive cleanup here.
