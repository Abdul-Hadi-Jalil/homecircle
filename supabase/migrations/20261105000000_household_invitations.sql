-- Invitation hashes are server-only; plaintext codes never enter PostgreSQL.
create function public.list_household_members(target uuid, page_limit integer, page_offset integer)
returns table(user_id uuid, display_name text, avatar_path text, role text, joined_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_member(target) then raise insufficient_privilege using message = 'Membership required'; end if;
  return query select m.user_id, p.display_name, p.avatar_path, m.role, m.joined_at
    from public.household_members m join public.profiles p on p.id = m.user_id
    where m.household_id = target order by m.joined_at, m.id
    limit least(greatest(page_limit, 1), 100) offset greatest(page_offset, 0);
end $$;
revoke all on function public.list_household_members(uuid,integer,integer) from public, anon, authenticated;
grant execute on function public.list_household_members(uuid,integer,integer) to homecircle_api;

create table public.household_invites (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  code_hash text not null unique check (code_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid references public.profiles(id) on delete set null,
  expires_at timestamptz not null,
  max_uses integer check (max_uses between 1 and 1000),
  uses_count integer not null default 0 check (uses_count >= 0),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);
create index household_invites_household_idx on public.household_invites(household_id);
alter table public.household_invites enable row level security;
revoke all on public.household_invites from public, anon, authenticated, homecircle_api;
grant select (id, household_id, created_by, expires_at, max_uses, uses_count, revoked_at, created_at)
  on public.household_invites to homecircle_api;
create policy invites_admin_read on public.household_invites for select to homecircle_api
  using (private.is_admin(household_id));

create function public.issue_household_invite(target uuid, digest text, expiry timestamptz, use_limit integer)
returns uuid language plpgsql security definer set search_path = '' as $$
declare result uuid;
begin
  perform 1 from public.households where id = target for update;
  if not private.is_admin(target) then raise insufficient_privilege using message = 'Admin required'; end if;
  if expiry <= clock_timestamp() or expiry > clock_timestamp() + interval '30 days' then
    raise check_violation using message = 'Invalid expiry';
  end if;
  update public.household_invites set revoked_at = clock_timestamp()
    where household_id = target and revoked_at is null;
  insert into public.household_invites(household_id, code_hash, created_by, expires_at, max_uses)
    values(target, digest, auth.uid(), expiry, use_limit) returning id into result;
  return result;
end $$;

create function public.revoke_household_invite(target uuid, invitation uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.households where id = target for update;
  if not private.is_admin(target) then raise insufficient_privilege using message = 'Admin required'; end if;
  update public.household_invites set revoked_at = coalesce(revoked_at, clock_timestamp())
    where id = invitation and household_id = target;
  return found;
end $$;

create function public.resolve_household_invite(digest text, redeem boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare invitation public.household_invites; home public.households; actor uuid := auth.uid(); member_role text; was_member boolean;
begin
  if actor is null then raise insufficient_privilege using message = 'Authentication required'; end if;
  select * into invitation from public.household_invites where code_hash = digest;
  if not found then return jsonb_build_object('status', 'invalid_invitation'); end if;
  -- All membership/invitation mutations lock the parent first, avoiding lock inversion.
  if redeem then
    perform 1 from public.households where id = invitation.household_id for update;
    select * into invitation from public.household_invites where code_hash = digest for update;
    if not found then return jsonb_build_object('status', 'invalid_invitation'); end if;
  end if;
  if invitation.revoked_at is not null then return jsonb_build_object('status', 'revoked_invitation'); end if;
  if invitation.expires_at <= clock_timestamp() then return jsonb_build_object('status', 'expired_invitation'); end if;
  select role into member_role from public.household_members
    where household_id = invitation.household_id and user_id = actor;
  was_member := member_role is not null;
  if member_role is null and invitation.max_uses is not null and invitation.uses_count >= invitation.max_uses then
    return jsonb_build_object('status', 'invitation_limit');
  end if;
  select * into home from public.households where id = invitation.household_id;
  if redeem and member_role is null then
    insert into public.household_members(household_id, user_id, role) values(home.id, actor, 'member');
    update public.household_invites set uses_count = uses_count + 1 where id = invitation.id;
    member_role := 'member';
  end if;
  return jsonb_build_object('status', 'ok', 'household_id', home.id, 'name', home.name,
    'already_member', was_member, 'role', member_role);
end $$;

-- Called and committed separately before preview/redemption so failures still consume attempts.
create table private.invite_attempts (user_id uuid primary key, bucket bigint not null, attempts integer not null);
revoke all on private.invite_attempts from public, anon, authenticated, homecircle_api;
create function public.consume_invite_attempt() returns boolean
language plpgsql security definer set search_path = '' as $$
declare period bigint := floor(extract(epoch from clock_timestamp()) / 300); count_used integer; actor uuid := auth.uid();
begin
  if actor is null then raise insufficient_privilege using message = 'Authentication required'; end if;
  insert into private.invite_attempts values(actor, period, 1)
    on conflict(user_id) do update set bucket = excluded.bucket,
      attempts = case when private.invite_attempts.bucket = excluded.bucket
        then least(private.invite_attempts.attempts + 1, 21) else 1 end
    returning attempts into count_used;
  return count_used <= 20;
end $$;

revoke all on function public.issue_household_invite(uuid,text,timestamptz,integer),
  public.revoke_household_invite(uuid,uuid), public.resolve_household_invite(text,boolean),
  public.consume_invite_attempt() from public, anon, authenticated;
grant execute on function public.issue_household_invite(uuid,text,timestamptz,integer),
  public.revoke_household_invite(uuid,uuid), public.resolve_household_invite(text,boolean),
  public.consume_invite_attempt() to homecircle_api;
