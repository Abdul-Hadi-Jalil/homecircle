-- Members may leave a household; the last administrator must transfer admin or delete it instead.
create function public.leave_household(target uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); member_role text;
begin
  if actor is null then raise insufficient_privilege using message = 'Authentication required'; end if;
  perform 1 from public.households where id = target for update;
  select role into member_role from public.household_members
    where household_id = target and user_id = actor;
  if member_role is null then raise no_data_found using message = 'Not a member'; end if;
  if member_role = 'admin' and (select count(*) from public.household_members
      where household_id = target and role = 'admin') <= 1 then
    raise check_violation using message = 'The last admin cannot leave';
  end if;
  delete from public.household_members where household_id = target and user_id = actor;
end $$;
revoke all on function public.leave_household(uuid) from public, anon, authenticated;
grant execute on function public.leave_household(uuid) to homecircle_api;
