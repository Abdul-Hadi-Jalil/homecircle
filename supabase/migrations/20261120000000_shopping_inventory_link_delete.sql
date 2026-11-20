-- Deleting a household cascades to inventory_items, shopping details and the
-- purchase ledger. Their inventory links had immediate NO ACTION checks, which
-- could fire before the cascade removed the referencing rows and block the
-- household deletion. Checking at commit lets a whole-household cascade finish,
-- while deleting a single referenced inventory item on its own is still refused.
alter table public.shopping_item_details
  alter constraint shopping_item_details_household_id_linked_inventory_item_i_fkey
  deferrable initially deferred;

alter table public.shopping_inventory_applications
  alter constraint shopping_inventory_applicatio_household_id_inventory_item__fkey
  deferrable initially deferred;
