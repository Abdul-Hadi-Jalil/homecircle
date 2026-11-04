-- Run as the migration owner, never as the API login.
create schema if not exists private;
revoke all on schema private from public;
revoke create on schema public from public;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'homecircle_api') then
    create role homecircle_api login noinherit nosuperuser nocreatedb nocreaterole
      noreplication nobypassrls;
  end if;
end $$;
-- Assign a unique password out of band; no password is committed in migrations.
grant usage on schema public, private, auth to homecircle_api;
grant usage on schema private to authenticated;
grant execute on function auth.uid() to homecircle_api;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 100),
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 100),
  description text check (char_length(description) <= 1000),
  image_path text,
  -- Retain households if the original creator's Auth account is deleted.
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('admin', 'member')),
  joined_at timestamptz not null default now(),
  unique (household_id, user_id)
);
create index household_members_user_id_idx on public.household_members(user_id);
create index households_created_by_idx on public.households(created_by);

create function private.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;
create trigger profiles_updated_at before update on public.profiles
  for each row execute function private.touch_updated_at();
create trigger households_updated_at before update on public.households
  for each row execute function private.touch_updated_at();

create function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, left(coalesce(new.raw_user_meta_data ->> 'display_name', ''), 100))
  on conflict (id) do nothing;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();
insert into public.profiles (id, display_name)
select id, left(coalesce(raw_user_meta_data ->> 'display_name', ''), 100) from auth.users
on conflict (id) do nothing;

-- These narrowly scoped definer helpers prevent recursive RLS membership queries.
-- The caller cannot choose an identity: it always comes from verified transaction context.
create function private.is_member(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.household_members
    where household_id = target and user_id = (select auth.uid()));
$$;
create function private.is_admin(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.household_members
    where household_id = target and user_id = (select auth.uid()) and role = 'admin');
$$;

alter table public.profiles enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;

create policy profiles_select_self on public.profiles for select
  to authenticated, homecircle_api using (id = (select auth.uid()));
create policy profiles_update_self on public.profiles for update
  to authenticated, homecircle_api using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
create policy households_select_member on public.households for select
  to authenticated, homecircle_api using (private.is_member(id));
create policy households_update_admin on public.households for update
  to authenticated, homecircle_api using (private.is_admin(id))
  with check (private.is_admin(id));
create policy households_delete_admin on public.households for delete
  to authenticated, homecircle_api using (private.is_admin(id));
create policy members_select_household on public.household_members for select
  to authenticated, homecircle_api using (private.is_member(household_id));

-- Explicit grants override Supabase's default public-schema table grants.
revoke all on public.profiles, public.households, public.household_members
  from anon, authenticated, homecircle_api;
grant select on public.profiles, public.households, public.household_members
  to authenticated, homecircle_api;
grant update (display_name, avatar_path) on public.profiles to authenticated, homecircle_api;
grant update (name, description, image_path), delete on public.households
  to authenticated, homecircle_api;

create function public.create_household(household_name text, household_description text default null)
returns public.households language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  created public.households;
begin
  if actor is null then raise insufficient_privilege using message = 'Authentication required'; end if;
  if household_name is null or char_length(btrim(household_name)) not between 1 and 100
      or char_length(household_description) > 1000 then
    raise check_violation using message = 'Invalid household';
  end if;
  insert into public.households (name, description, created_by)
    values (btrim(household_name), household_description, actor) returning * into created;
  insert into public.household_members (household_id, user_id, role)
    values (created.id, actor, 'admin');
  return created;
end $$;

-- No direct membership writes. RPCs lock the household row to serialize admin changes.
create function public.set_member_role(target_household uuid, target_user uuid, new_role text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.households where id = target_household for update;
  if not private.is_admin(target_household) then
    raise insufficient_privilege using message = 'Admin required';
  end if;
  if new_role is null or new_role not in ('admin', 'member') then
    raise check_violation using message = 'Invalid role';
  end if;
  if new_role = 'member' and exists (
    select 1 from public.household_members where household_id = target_household
      and user_id = target_user and role = 'admin'
  ) and (select count(*) from public.household_members
    where household_id = target_household and role = 'admin') <= 1 then
    raise check_violation using message = 'The last admin cannot be demoted';
  end if;
  update public.household_members set role = new_role
    where household_id = target_household and user_id = target_user;
end $$;

create function public.remove_household_member(target_household uuid, target_user uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.households where id = target_household for update;
  if not private.is_admin(target_household) then
    raise insufficient_privilege using message = 'Admin required';
  end if;
  if exists (select 1 from public.household_members where household_id = target_household
    and user_id = target_user and role = 'admin') and (
      select count(*) from public.household_members
      where household_id = target_household and role = 'admin'
    ) <= 1 then
    raise check_violation using message = 'The last admin cannot be removed';
  end if;
  delete from public.household_members
    where household_id = target_household and user_id = target_user;
end $$;

-- Account deletion must not silently orphan a household via FK cascades.
create function private.guard_profile_deletion() returns trigger
language plpgsql security definer set search_path = '' as $$
declare household uuid;
begin
  for household in select household_id from public.household_members
    where user_id = old.id and role = 'admin' order by household_id
  loop
    perform 1 from public.households where id = household for update;
    if (select count(*) from public.household_members
        where household_id = household and role = 'admin') <= 1 then
      raise check_violation using message = 'Transfer admin or delete household before account deletion';
    end if;
  end loop;
  return old;
end $$;
create trigger profiles_guard_deletion before delete on public.profiles
  for each row execute function private.guard_profile_deletion();

-- Functions default to PUBLIC execution in PostgreSQL: revoke it explicitly.
revoke all on all functions in schema private from public, anon, authenticated, homecircle_api;
grant execute on function private.is_member(uuid), private.is_admin(uuid)
  to authenticated, homecircle_api;
revoke all on function public.create_household(text, text),
  public.set_member_role(uuid, uuid, text), public.remove_household_member(uuid, uuid)
  from public, anon;
grant execute on function public.create_household(text, text),
  public.set_member_role(uuid, uuid, text), public.remove_household_member(uuid, uuid)
  to authenticated, homecircle_api;
