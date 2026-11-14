-- Forward migration. Requires M0--M3; no task or inventory data is rewritten.
-- M3 reserved Shopping without a write API. Only completed legacy rows require
-- purchase attribution review. Other existing parents receive empty details below.
do $$ begin
 if exists(select 1 from public.household_tasks where task_type='shopping' and status='completed') then
   raise exception 'Completed legacy shopping parents require reviewed purchase backfill';
 end if;
end $$;
create table public.shopping_item_details (
 task_id uuid primary key, household_id uuid not null,
 quantity numeric(15,3) check(quantity>0 and quantity<=999999999999.999), unit text check(unit in ('piece','pack','kg','g','L','mL','bottle','box','roll')),
 linked_inventory_item_id uuid,
 purchase_id uuid unique, actual_quantity numeric(15,3) check(actual_quantity>0 and actual_quantity<=999999999999.999),
 purchased_by uuid, purchased_at timestamptz,
 purchase_price numeric(15,2) check(purchase_price>=0 and purchase_price<=9999999999999.99), currency_code text,
 inventory_updated_at timestamptz,
 created_at timestamptz not null default clock_timestamp(), updated_at timestamptz not null default clock_timestamp(),
 unique(household_id,task_id),
 foreign key(household_id,task_id) references public.household_tasks(household_id,id) on delete cascade,
 foreign key(household_id,linked_inventory_item_id) references public.inventory_items(household_id,id),
 check((purchase_price is null)=(currency_code is null)),
 check(currency_code is null or currency_code in ('PKR','USD','EUR','GBP','AED','SAR','INR','CAD','AUD','JPY','CNY')),
 check((purchase_id is null and purchased_by is null and purchased_at is null and actual_quantity is null
   and purchase_price is null and inventory_updated_at is null)
   or (purchase_id is not null and purchased_by is not null and purchased_at is not null))
);
create index shopping_inventory on public.shopping_item_details(household_id,linked_inventory_item_id);
create index shopping_purchases on public.shopping_item_details(household_id,purchased_at desc,task_id);

-- Survives undo and subsequent purchase cycles. The key is a server-generated purchase UUID.
create table public.shopping_inventory_applications (
 purchase_id uuid primary key, household_id uuid not null, task_id uuid not null,
 inventory_item_id uuid not null, quantity numeric(15,3) not null check(quantity>0 and quantity<=999999999999.999),
 applied_by uuid not null, applied_at timestamptz not null default clock_timestamp(),
 foreign key(household_id,task_id) references public.shopping_item_details(household_id,task_id) on delete cascade,
 foreign key(household_id,inventory_item_id) references public.inventory_items(household_id,id)
);

create function private.shopping_consistency() returns trigger
language plpgsql security definer set search_path='' as $$
declare t public.household_tasks; d public.shopping_item_details; target uuid;
begin
 if TG_TABLE_NAME='household_tasks' then target:=coalesce(new.id,old.id);
 else target:=coalesce(new.task_id,old.task_id); end if;
 select * into t from public.household_tasks where id=target;
 if not found then return null; end if;
 select * into d from public.shopping_item_details where task_id=target;
 if (t.task_type='shopping')<>found then
   raise check_violation using message='Shopping task requires exactly one shopping detail';
 end if;
 if t.task_type='shopping' and ((t.status='completed')<>(d.purchase_id is not null)
   or (d.purchased_at is distinct from t.completed_at)) then
   raise check_violation using message='Shopping completion metadata is inconsistent';
 end if;
 if t.task_type='shopping' and (d.inventory_updated_at is not null) <> exists(
   select 1 from public.shopping_inventory_applications a where a.purchase_id=d.purchase_id
   and a.household_id=d.household_id and a.task_id=d.task_id) then
   raise check_violation using message='Inventory application metadata is inconsistent';
 end if;
 return null;
end $$;
revoke all on function private.shopping_consistency() from public,anon,authenticated,homecircle_api;
create constraint trigger shopping_task_consistency after insert or update or delete on public.household_tasks
 deferrable initially deferred for each row execute function private.shopping_consistency();
create constraint trigger shopping_detail_consistency after insert or update or delete on public.shopping_item_details
 deferrable initially deferred for each row execute function private.shopping_consistency();
create constraint trigger shopping_application_consistency after insert on public.shopping_inventory_applications
 deferrable initially deferred for each row execute function private.shopping_consistency();

create function private.validate_shopping_application() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.applied_by is distinct from private.current_actor() or not exists(
   select 1 from public.shopping_item_details d join public.household_tasks t on t.id=d.task_id
   and t.household_id=d.household_id where d.purchase_id=new.purchase_id and d.task_id=new.task_id
   and d.household_id=new.household_id and d.linked_inventory_item_id=new.inventory_item_id
   and d.actual_quantity=new.quantity and t.status='completed' and t.deleted_at is null) then
   raise check_violation using message='Invalid purchase inventory application';
 end if;
 return new;
end $$;
revoke all on function private.validate_shopping_application() from public,anon,authenticated,homecircle_api;
create trigger shopping_application_validate before insert on public.shopping_inventory_applications
 for each row execute function private.validate_shopping_application();

create function private.validate_shopping_detail() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if TG_OP='UPDATE' and (new.task_id<>old.task_id or new.household_id<>old.household_id) then
   raise check_violation using message='Shopping ownership is immutable';
 end if;
 if TG_OP='UPDATE' and old.purchase_id is not null and new.purchase_id is not null and
   row(new.purchase_id,new.actual_quantity,new.purchased_by,new.purchased_at,new.purchase_price,
       new.currency_code,new.quantity,new.unit,new.linked_inventory_item_id) is distinct from
   row(old.purchase_id,old.actual_quantity,old.purchased_by,old.purchased_at,old.purchase_price,
       old.currency_code,old.quantity,old.unit,old.linked_inventory_item_id) then
   raise check_violation using message='Reopen before changing purchase metadata';
 end if;
 if new.purchase_id is not null and (TG_OP='INSERT' or new.purchase_id is distinct from old.purchase_id)
   and new.purchased_by is distinct from private.current_actor() then
   raise check_violation using message='Purchase actor must match verified identity';
 end if;
 if new.linked_inventory_item_id is not null and (TG_OP='INSERT'
   or new.linked_inventory_item_id is distinct from old.linked_inventory_item_id or new.unit is distinct from old.unit)
   and not exists(select 1 from public.inventory_items i where i.id=new.linked_inventory_item_id
     and i.household_id=new.household_id and i.deleted_at is null
     and (i.item_type='durable' or i.unit=new.unit)) then
   raise check_violation using message='Linked inventory or unit is unavailable';
 end if;
 new.updated_at:=clock_timestamp();
 return new;
end $$;
revoke all on function private.validate_shopping_detail() from public,anon,authenticated,homecircle_api;
create trigger shopping_detail_validate before insert or update on public.shopping_item_details
 for each row execute function private.validate_shopping_detail();

alter table public.shopping_item_details enable row level security;
alter table public.shopping_inventory_applications enable row level security;
revoke all on public.shopping_item_details,public.shopping_inventory_applications from public,anon,authenticated,homecircle_api;
grant select on public.shopping_item_details,public.shopping_inventory_applications to authenticated,homecircle_api;
grant insert on public.shopping_item_details,public.shopping_inventory_applications to homecircle_api;
grant update(quantity,unit,linked_inventory_item_id,purchase_id,actual_quantity,purchased_by,purchased_at,
 purchase_price,currency_code,inventory_updated_at) on public.shopping_item_details to homecircle_api;
create policy shopping_read on public.shopping_item_details for select to authenticated,homecircle_api using(private.is_member(household_id));
create policy shopping_insert on public.shopping_item_details for insert to homecircle_api with check(private.is_member(household_id));
create policy shopping_update on public.shopping_item_details for update to homecircle_api using(private.is_member(household_id)) with check(private.is_member(household_id));
create policy shopping_applications_read on public.shopping_inventory_applications for select to authenticated,homecircle_api using(private.is_member(household_id));
create policy shopping_applications_insert on public.shopping_inventory_applications for insert to homecircle_api
 with check(private.is_member(household_id) and applied_by=private.current_actor());

-- Preserve any outstanding/cancelled reserved Shopping parents without inventing
-- quantities, links or purchase attribution. Their task IDs/revisions stay intact.
insert into public.shopping_item_details(task_id,household_id)
 select id,household_id from public.household_tasks where task_type='shopping';
