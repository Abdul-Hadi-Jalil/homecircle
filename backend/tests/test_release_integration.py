"""Five-actor isolation acceptance, guarded by the disposable-project fixture."""

import pytest

from tests.test_database_integration import as_actor, create, user
from tests.test_database_integration import database as database  # noqa: F401
from tests.test_inventory_integration import insert_item

pytestmark = pytest.mark.integration


def test_five_actor_household_inventory_matrix(database):
    admin, member, other_member, dual_member, nonmember = [user(database) for _ in range(5)]
    home_a = create(database, admin)
    home_b = create(database, dual_member)
    database.execute("RESET ROLE")
    for home, actor in [(home_a, member), (home_a, dual_member), (home_b, other_member)]:
        database.execute(
            "INSERT INTO public.household_members(household_id,user_id) VALUES(%s,%s)",
            (home, actor),
        )
    as_actor(database, admin, "homecircle_api")
    item_a = insert_item(database, home_a, admin)
    as_actor(database, other_member, "homecircle_api")
    item_b = insert_item(database, home_b, other_member)
    expected = {
        admin: {home_a},
        member: {home_a},
        other_member: {home_b},
        dual_member: {home_a, home_b},
        nonmember: set(),
    }
    for actor, homes in expected.items():
        as_actor(database, actor, "homecircle_api")
        rows = database.execute(
            "SELECT household_id FROM public.inventory_items WHERE id IN (%s,%s)",
            (item_a, item_b),
        ).fetchall()
        assert {row["household_id"] for row in rows} == homes
        for home in (home_a, home_b):
            assert database.execute(
                "SELECT public.lock_inventory_household(%s) AS allowed", (home,)
            ).fetchone()["allowed"] == (home in homes)
        updated = database.execute(
            # The update policy requires the writer to stamp itself, as the app does.
            "UPDATE public.inventory_items SET quantity=quantity+1, updated_by=%s "
            "WHERE id IN (%s,%s) RETURNING household_id",
            (actor, item_a, item_b),
        ).fetchall()
        assert {row["household_id"] for row in updated} == homes
