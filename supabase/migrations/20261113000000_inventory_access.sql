-- Lock as owner, authorize as the verified actor. SELECT FOR SHARE on households
-- as homecircle_api would also be subject to its admin-only UPDATE RLS policy.
create function public.lock_inventory_household(target uuid) returns boolean
language plpgsql security definer set search_path='' as $$
begin
  perform 1 from public.households where id=target for share;
  return found and private.is_member(target);
end $$;
revoke all on function public.lock_inventory_household(uuid) from public,anon,authenticated;
grant execute on function public.lock_inventory_household(uuid) to homecircle_api;

-- No profile RLS expansion or member-list pagination limit. Former participants
-- remain attributable while their profile exists; deleted profiles return NULL.
create function public.inventory_actor_name(target uuid, actor uuid) returns text
language sql stable security definer set search_path='' as $$
  select p.display_name from public.profiles p where p.id=actor
    and private.is_member(target) and (
      exists(select 1 from public.household_members m
        where m.household_id=target and m.user_id=actor)
      or exists(select 1 from public.inventory_activity a
        where a.household_id=target and a.actor_user_id=actor)
    );
$$;
revoke all on function public.inventory_actor_name(uuid,uuid) from public,anon,authenticated;
grant execute on function public.inventory_actor_name(uuid,uuid) to homecircle_api;

alter table private.inventory_uploads add column finalized boolean not null default false;
grant update(finalized) on private.inventory_uploads to homecircle_api;
create policy inventory_upload_finalize on private.inventory_uploads for update to homecircle_api
 using(actor_id=private.current_actor()) with check(actor_id=private.current_actor());

create function private.inventory_photo_cleanup(object_name text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.inventory_uploads u where u.path=object_name and u.finalized
   and private.is_member(u.household_id))
   and not exists(select 1 from public.inventory_items i where i.photo_path=object_name);
$$;
revoke all on function private.inventory_photo_cleanup(text) from public,anon;
grant execute on function private.inventory_photo_cleanup(text) to authenticated;
create policy inventory_photo_delete on storage.objects for delete to authenticated
 using(bucket_id='inventory-photos' and private.inventory_photo_cleanup(name));
-- PostgreSQL DELETE also requires SELECT visibility of orphan objects.
create policy inventory_photo_orphan_read on storage.objects for select to authenticated
 using(bucket_id='inventory-photos' and
   (private.inventory_photo_cleanup(name) or private.inventory_upload_allowed(name)));
