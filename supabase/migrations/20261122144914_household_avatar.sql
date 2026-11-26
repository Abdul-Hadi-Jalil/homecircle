-- Household avatar preset (icon key) and richer invitation preview.
alter table public.households add column avatar_key text
  check (avatar_key is null or avatar_key in ('cottage', 'apartment', 'forest', 'pets', 'favorite'));
grant update (avatar_key) on public.households to authenticated, homecircle_api;

-- Preview now reports the member count and avatar so the join screen can confirm the household.
create or replace function public.resolve_household_invite(digest text, redeem boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare invitation public.household_invites; home public.households; actor uuid := auth.uid(); member_role text; was_member boolean; members integer;
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
  select count(*) into members from public.household_members where household_id = home.id;
  return jsonb_build_object('status', 'ok', 'household_id', home.id, 'name', home.name,
    'already_member', was_member, 'role', member_role,
    'member_count', members, 'avatar_key', home.avatar_key);
end $$;
