"""Write-capable SQL checks run exclusively via the guarded disposable-project fixture."""

import asyncio
import os
from concurrent.futures import ThreadPoolExecutor
from decimal import Decimal
from threading import Barrier

import psycopg
import pytest
from psycopg.rows import dict_row

from app.core.exceptions import AppError
from app.models.auth import AuthenticatedUser
from app.repositories.shopping import ShoppingRepository
from app.schemas.shopping import ApplyInventory, Purchase, ShoppingCreate, ShoppingUpdate
from app.schemas.task import Assignment, Revision
from app.services.shopping import ShoppingService
from tests.test_database_integration import as_actor
from tests.test_database_integration import database as database  # noqa: F401
from tests.test_inventory_integration import FixtureRepository, insert_item, seed

pytestmark = pytest.mark.integration


class FixtureShopping(ShoppingRepository):
    def __init__(self, connection):
        self.connection = connection

    transaction = FixtureRepository.transaction


def service(connection):
    result = ShoppingService(FixtureShopping(connection))
    result.inventory = FixtureRepository(connection)
    return result


def check_constraints(connection):
    connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
    connection.execute("SET CONSTRAINTS ALL DEFERRED")


async def test_shopping_member_crud_and_outsider_rls(database):
    _, member, outsider, home = seed(database)
    shopping = service(database)
    actor = AuthenticatedUser(member, None)
    row = await shopping.create(
        actor, home, ShoppingCreate(title="Rice", quantity="5", unit="kg", priority="high")
    )
    check_constraints(database)
    assert (
        await shopping.repository.listing(member, home, {"search": "Rice", "priority": "high"})
    )["items"][0]["id"] == row["id"]
    row = await shopping.update(
        actor,
        home,
        row["id"],
        ShoppingUpdate(expected_revision=1, assigned_to=member, title="Basmati"),
    )
    assert row["revision"] == 2
    as_actor(database, outsider)
    assert database.execute("SELECT task_id FROM public.shopping_item_details").fetchall() == []
    with pytest.raises(AppError):
        await shopping.detail(AuthenticatedUser(outsider, None), home, row["id"])
    as_actor(database, member)
    with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
        database.execute(
            "UPDATE public.shopping_item_details SET quantity=100 WHERE task_id=%s", (row["id"],)
        )


async def test_shopping_cross_household_link_nonshopping_and_purchase_invariant(database):
    _, member, outsider, home = seed(database)
    shopping = service(database)
    actor = AuthenticatedUser(member, None)
    row = await shopping.create(actor, home, ShoppingCreate(title="Milk"))
    check_constraints(database)
    as_actor(database, member, "homecircle_api")
    with pytest.raises(psycopg.errors.CheckViolation), database.transaction():
        database.execute(
            "UPDATE public.household_tasks SET status='completed',"
            "completed_at=clock_timestamp(),updated_by=%s WHERE id=%s",
            (member, row["id"]),
        )
        database.execute("SET CONSTRAINTS ALL IMMEDIATE")
    with pytest.raises(psycopg.errors.CheckViolation), database.transaction():
        database.execute(
            "UPDATE public.household_tasks SET task_type='general',updated_by=%s WHERE id=%s",
            (member, row["id"]),
        )
        database.execute("SET CONSTRAINTS ALL IMMEDIATE")
    with pytest.raises(psycopg.errors.CheckViolation), database.transaction():
        database.execute(
            "UPDATE public.shopping_item_details SET quantity=%s WHERE task_id=%s",
            ("NaN", row["id"]),
        )
    with pytest.raises(AppError):
        await shopping.update(
            actor, home, row["id"], ShoppingUpdate(expected_revision=1, assigned_to=outsider)
        )
    # A real inventory row in a second household cannot become this request's link.
    database.execute("RESET ROLE")
    other = database.execute(
        "INSERT INTO public.households(name) VALUES(%s) RETURNING id", ("Foreign",)
    ).fetchone()["id"]
    foreign = insert_item(database, other, outsider)
    with pytest.raises(AppError):
        await shopping.update(
            actor,
            home,
            row["id"],
            ShoppingUpdate(expected_revision=1, linked_inventory_item_id=foreign),
        )
    check_constraints(database)


async def test_shopping_purchase_stock_idempotency_undo_history_and_summary(database):
    _, member, _, home = seed(database)
    as_actor(database, member, "homecircle_api")
    item = insert_item(database, home, member)
    shopping = service(database)
    actor = AuthenticatedUser(member, None)
    row = await shopping.create(
        actor,
        home,
        ShoppingCreate(title="Rice", quantity="5", unit="kg", linked_inventory_item_id=item),
    )
    row = await shopping.transition(
        actor,
        home,
        row["id"],
        Purchase(expected_revision=1, purchase_price="32.50", currency_code="USD"),
        "completed",
    )
    check_constraints(database)
    assert row["purchased_by"] == member
    data = ApplyInventory(expected_revision=2, purchase_id=row["purchase_id"])
    await shopping.apply_inventory(actor, home, row["id"], data)
    assert (await shopping.apply_inventory(actor, home, row["id"], data))["already_applied"]
    check_constraints(database)
    assert database.execute(
        "SELECT quantity FROM public.inventory_items WHERE id=%s", (item,)
    ).fetchone()["quantity"] == Decimal("8")
    row = await shopping.transition(actor, home, row["id"], Revision(expected_revision=3), "open")
    check_constraints(database)
    assert row["purchased_at"] is None and row["purchase_id"] is None
    history = await shopping.repository.history(member, home, {})
    assert history["items"][0]["purchase"]["purchase_price"] == "32.50"
    counts = await shopping.repository.summary(member, home, {})
    assert (
        counts["active"] == 1 and counts["purchased"] == 0 and counts["completion_percentage"] == 0
    )


async def test_shopping_activity_failure_rolls_back_purchase(database):
    _, member, _, home = seed(database)
    shopping = service(database)
    actor = AuthenticatedUser(member, None)
    row = await shopping.create(actor, home, ShoppingCreate(title="Eggs"))

    async def fail(*args):
        raise RuntimeError("Intentional event failure")

    shopping.repository.event = fail
    with pytest.raises(RuntimeError):
        await shopping.transition(
            actor, home, row["id"], Purchase(expected_revision=1), "completed"
        )
    check_constraints(database)
    current = await shopping.detail(actor, home, row["id"])
    assert current["revision"] == 1 and current["purchased_at"] is None


@pytest.mark.parametrize("operation", ["claim", "purchase", "apply"])
def test_shopping_real_concurrent_claim_purchase_and_stock(database, operation):
    # The fixture validates target identity before independent committed connections.
    url = os.environ["SUPABASE_TEST_DATABASE_URL"]
    tls = {"sslmode": "verify-full", "connect_timeout": 10}
    if cert := os.getenv("SUPABASE_TEST_DATABASE_SSLROOTCERT"):
        tls["sslrootcert"] = cert
    home = None
    actors = []
    try:
        with psycopg.connect(url, row_factory=dict_row, **tls) as c:
            admin, member, another, home = seed(c)
            actors = [admin, member, another]
            c.execute("RESET ROLE")
            c.execute(
                "INSERT INTO public.household_members(household_id,user_id) VALUES(%s,%s)",
                (home, another),
            )
            item = insert_item(c, home, member)

            async def create():
                shopping = service(c)
                actor = AuthenticatedUser(member, None)
                result = await shopping.create(
                    actor,
                    home,
                    ShoppingCreate(
                        title="Concurrent rice",
                        quantity="5",
                        unit="kg",
                        linked_inventory_item_id=item,
                    ),
                )
                if operation == "apply":
                    result = await shopping.transition(
                        actor, home, result["id"], Purchase(expected_revision=1), "completed"
                    )
                return result

            row = asyncio.run(create())
        barrier = Barrier(2, timeout=20)

        def worker(actor):
            with psycopg.connect(url, row_factory=dict_row, **tls) as c:
                barrier.wait()

                async def run():
                    shopping = service(c)
                    user = AuthenticatedUser(actor, None)
                    try:
                        if operation == "claim":
                            await shopping.assignment(
                                user,
                                home,
                                row["id"],
                                Assignment(expected_revision=1, operation="claim"),
                            )
                        elif operation == "purchase":
                            await shopping.transition(
                                user, home, row["id"], Purchase(expected_revision=1), "completed"
                            )
                        else:
                            await shopping.apply_inventory(
                                user,
                                home,
                                row["id"],
                                ApplyInventory(expected_revision=2, purchase_id=row["purchase_id"]),
                            )
                        return "ok"
                    except AppError as error:
                        return error.code

                return asyncio.run(run())

        with ThreadPoolExecutor(max_workers=2) as pool:
            outcomes = sorted(pool.map(worker, [member, another]))
        assert outcomes == (["ok", "ok"] if operation == "apply" else ["ok", "revision_conflict"])
        with psycopg.connect(url, row_factory=dict_row, **tls) as c:
            if operation == "apply":
                assert c.execute(
                    "SELECT quantity FROM public.inventory_items WHERE id=%s", (item,)
                ).fetchone()["quantity"] == Decimal("8")
                assert (
                    c.execute(
                        "SELECT count(*) AS n FROM public.shopping_inventory_applications "
                        "WHERE task_id=%s",
                        (row["id"],),
                    ).fetchone()["n"]
                    == 1
                )
            else:
                assert (
                    c.execute(
                        "SELECT revision FROM public.household_tasks WHERE id=%s", (row["id"],)
                    ).fetchone()["revision"]
                    == 2
                )
    finally:
        with psycopg.connect(url, **tls) as c:
            if home:
                c.execute("DELETE FROM public.households WHERE id=%s", (home,))
            for actor in actors:
                c.execute("DELETE FROM auth.users WHERE id=%s", (actor,))
