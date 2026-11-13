create table public.inventory_categories (
 id uuid primary key default gen_random_uuid(), household_id uuid references public.households(id) on delete cascade,
 name text not null check (length(btrim(name)) between 1 and 80),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index inventory_category_name on public.inventory_categories
 (coalesce(household_id,'00000000-0000-0000-0000-000000000000'::uuid),lower(btrim(name)));
insert into public.inventory_categories(name) values ('Groceries'),('Kitchen'),('Cleaning'),('Bathroom'),('Appliances'),('Electronics'),('Furniture'),('Other');

create table public.inventory_items (
 id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
 category_id uuid references public.inventory_categories(id), name text not null check (length(btrim(name)) between 1 and 150),
 item_type text not null check (item_type in ('consumable','durable')),
 quantity numeric(15,3), unit text, minimum_quantity numeric(15,3), condition text,
 location text check(length(location)<=150), photo_path text, notes text check(length(notes)<=4000),
 purchase_date date, last_service_date date,
 created_by uuid not null, updated_by uuid not null,
 created_at timestamptz not null default clock_timestamp(), updated_at timestamptz not null default clock_timestamp(),
 deleted_at timestamptz, revision bigint not null default 1 check(revision>0),
 unique(household_id,id),
 check(quantity>=0 and minimum_quantity>=0),
 check ((item_type='consumable' and quantity is not null and unit in ('piece','pack','kg','g','L','mL','bottle','box','roll') and condition is null and purchase_date is null and last_service_date is null)
   or (item_type='durable' and condition in ('working','needs_repair','broken') and condition is not null and quantity is null and unit is null and minimum_quantity is null)),
 check (item_type <> 'consumable' or unit is not null),
 check(photo_path is null or photo_path ~ ('^' || household_id::text || '/' || id::text || '/[0-9a-f-]+\.(jpg|png|webp)$'))
);
create index inventory_household_active on public.inventory_items(household_id,deleted_at,updated_at desc);
create index inventory_category on public.inventory_items(category_id);
create index inventory_type on public.inventory_items(household_id,item_type);

create table public.inventory_activity (
 id uuid primary key default gen_random_uuid(), household_id uuid not null,
 inventory_item_id uuid not null, actor_user_id uuid not null,
 action text not null check(action in ('created','updated','quantity_changed','condition_changed','photo_changed','archived','restored')),
 changes jsonb, created_at timestamptz not null default clock_timestamp(),
 foreign key(household_id,inventory_item_id) references public.inventory_items(household_id,id) on delete cascade
);
create index inventory_activity_item on public.inventory_activity(household_id,inventory_item_id,created_at desc,id);

create function private.validate_inventory_category() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.category_id is not null and not exists(select 1 from public.inventory_categories
   where id=new.category_id and (household_id is null or household_id=new.household_id)) then
   raise check_violation using message='Category is not available for this household';
 end if;
 if TG_OP='UPDATE' and (new.household_id<>old.household_id or new.created_by<>old.created_by or new.id<>old.id) then
   raise check_violation using message='Inventory ownership is immutable';
 end if;
 return new;
end $$;
revoke all on function private.validate_inventory_category() from public,anon,authenticated,homecircle_api;
create trigger inventory_validate before insert or update on public.inventory_items
 for each row execute function private.validate_inventory_category();

alter table public.inventory_categories enable row level security;
alter table public.inventory_items enable row level security;
alter table public.inventory_activity enable row level security;
revoke all on public.inventory_categories,public.inventory_items,public.inventory_activity from public,anon,authenticated,homecircle_api;
grant select on public.inventory_categories,public.inventory_items,public.inventory_activity to authenticated,homecircle_api;
grant insert on public.inventory_categories,public.inventory_items,public.inventory_activity to homecircle_api;
grant update(name,category_id,item_type,quantity,unit,minimum_quantity,condition,location,photo_path,notes,purchase_date,last_service_date,updated_by,updated_at,deleted_at,revision)
 on public.inventory_items to homecircle_api;
create policy inventory_category_read on public.inventory_categories for select to authenticated,homecircle_api
 using(household_id is null or private.is_member(household_id));
create policy inventory_category_insert on public.inventory_categories for insert to homecircle_api
 with check(household_id is not null and private.is_member(household_id));
create policy inventory_read on public.inventory_items for select to authenticated,homecircle_api using(private.is_member(household_id));
create policy inventory_insert on public.inventory_items for insert to homecircle_api
 with check(private.is_member(household_id) and created_by=private.current_actor() and updated_by=private.current_actor());
create policy inventory_update on public.inventory_items for update to homecircle_api
 using(private.is_member(household_id)) with check(private.is_member(household_id) and updated_by=private.current_actor());
create policy inventory_activity_read on public.inventory_activity for select to authenticated,homecircle_api using(private.is_member(household_id));
create policy inventory_activity_insert on public.inventory_activity for insert to homecircle_api
 with check(private.is_member(household_id) and actor_user_id=private.current_actor());

-- Reuse the approved inventory-photos bucket. Only the server's exact attached
-- object path is readable; no direct client writes. Uploads use the API DB role
-- to create short-lived, random-path upload authorizations (see following migration).
drop policy homecircle_private_object_read on storage.objects;
create policy homecircle_private_object_read on storage.objects for select to authenticated
 using(bucket_id in ('household-images','repair-attachments','chat-attachments')
 and private.is_member(private.object_household(name)));
