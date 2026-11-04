-- Keep the API role NOINHERIT and without Auth schema access. Expose only the
-- current transaction's actor ID through an owner-executed, argument-free helper.
create function private.current_actor() returns uuid
language sql stable security definer set search_path = '' as $$
  select auth.uid();
$$;
revoke all on function private.current_actor() from public, anon;
grant execute on function private.current_actor() to authenticated, homecircle_api;

alter policy profiles_select_self on public.profiles
  using (id = (select private.current_actor()));
alter policy profiles_update_self on public.profiles
  using (id = (select private.current_actor()))
  with check (id = (select private.current_actor()));
