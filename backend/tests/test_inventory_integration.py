"""Actual inventory RLS and concurrency checks: disposable hosted project only.

The imported fixture refuses the application project before any writes. Ordinary
tests roll back. The concurrent case commits only generated IDs and cleans them.
"""

import asyncio
import os
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager
from decimal import Decimal
from threading import Barrier
from uuid import uuid4

import psycopg
import pytest
from psycopg.rows import dict_row

from app.core.exceptions import AppError
from app.models.auth import AuthenticatedUser
from app.repositories.inventory import InventoryRepository
from app.schemas.inventory import InventoryQuantityUpdate
from app.services.inventory import InventoryService
from tests.test_database_integration import as_actor, create, user
from tests.test_database_integration import database as database  # noqa: F401

pytestmark = pytest.mark.integration


def seed(connection):
    admin, member, outsider = user(connection), user(connection), user(connection)
    household = create(connection, admin)
    connection.execute("RESET ROLE")
    connection.execute(
        "INSERT INTO public.household_members(household_id,user_id) VALUES(%s,%s)",
        (household, member),
    )
    return admin, member, outsider, household


def insert_item(connection, household, actor):
    return connection.execute(
        "INSERT INTO public.inventory_items(household_id,name,item_type,quantity,unit,"
        "minimum_quantity,created_by,updated_by) VALUES(%s,'Rice','consumable',3,'kg',1,%s,%s) "
        "RETURNING id",
        (household, actor, actor),
    ).fetchone()["id"]


def test_inventory_member_writes_and_outsider_isolation(database):
    _, member, outsider, household = seed(database)
    as_actor(database, member, "homecircle_api")
    assert database.execute(
        "SELECT public.lock_inventory_household(%s) AS ok", (household,)
    ).fetchone()["ok"]
    item_id = insert_item(database, household, member)
    database.execute("UPDATE public.inventory_items SET quantity=2 WHERE id=%s", (item_id,))
    as_actor(database, outsider, "homecircle_api")
    assert not database.execute(
        "SELECT public.lock_inventory_household(%s) AS ok", (household,)
    ).fetchone()["ok"]
    assert not database.execute(
        "SELECT id FROM public.inventory_items WHERE id=%s", (item_id,)
    ).fetchall()
    with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
        insert_item(database, household, outsider)


def test_inventory_category_scope_and_actor_name(database):
    admin, member, _, household = seed(database)
    other = create(database, admin)
    as_actor(database, admin, "homecircle_api")
    category = database.execute(
        "INSERT INTO public.inventory_categories(household_id,name) "
        "VALUES(%s,'Private') RETURNING id",
        (other,),
    ).fetchone()["id"]
    as_actor(database, member, "homecircle_api")
    item_id = insert_item(database, household, member)
    with pytest.raises(psycopg.errors.CheckViolation), database.transaction():
        database.execute(
            "UPDATE public.inventory_items SET category_id=%s WHERE id=%s", (category, item_id)
        )
    database.execute(
        "INSERT INTO public.inventory_activity"
        "(household_id,inventory_item_id,actor_user_id,action) "
        "VALUES(%s,%s,%s,'created')",
        (household, item_id, member),
    )
    assert (
        database.execute(
            "SELECT public.inventory_actor_name(%s,%s) AS name", (household, member)
        ).fetchone()["name"]
        is not None
    )
    assert (
        database.execute(
            "SELECT public.inventory_actor_name(%s,%s) AS name", (other, admin)
        ).fetchone()["name"]
        is None
    )


class AsyncCursor:
    def __init__(self, cursor):
        self.cursor = cursor

    async def fetchone(self):
        return self.cursor.fetchone()

    async def fetchall(self):
        return self.cursor.fetchall()


class AsyncConnectionAdapter:
    def __init__(self, connection):
        self.connection = connection

    async def execute(self, query, args=None):
        return AsyncCursor(self.connection.execute(query, args))


class FixtureRepository(InventoryRepository):
    def __init__(self, connection):
        self.connection = connection

    @asynccontextmanager
    async def transaction(self, actor, household):
        with self.connection.transaction():
            as_actor(self.connection, actor, "homecircle_api")
            c = AsyncConnectionAdapter(self.connection)
            allowed = await (
                await c.execute("SELECT public.lock_inventory_household(%s) AS ok", (household,))
            ).fetchone()
            if not allowed["ok"]:
                raise AppError(404, "not_found", "Household not found")
            yield c


async def test_inventory_repository_archive_restore_activity_and_revisions(database):
    _, member, outsider, household = seed(database)
    repo = FixtureRepository(database)
    service = InventoryService(repo)
    as_actor(database, member, "homecircle_api")
    item_id = insert_item(database, household, member)
    actor = AuthenticatedUser(member, None)
    await service.quantity(
        actor,
        household,
        item_id,
        InventoryQuantityUpdate(operation="set", amount="2", expected_revision=1),
    )
    with pytest.raises(AppError) as error:
        await service.quantity(
            actor,
            household,
            item_id,
            InventoryQuantityUpdate(operation="set", amount="0", expected_revision=1),
        )
    assert error.value.status == 409
    await service.archive(actor, household, item_id, 2)
    filters = {"archived": True, "sort": "updated", "page": 1, "page_size": 20}
    archived = await repo.list(member, household, filters)
    assert archived["items"][0]["id"] == item_id
    assert (await repo.detail(member, household, item_id))["deleted_at"] is not None
    events = await repo.activity(member, household, item_id, 1, 20)
    assert events["items"][0]["actor_name"] is not None
    await service.archive(actor, household, item_id, 3, restore=True)
    assert (await repo.detail(member, household, item_id))["deleted_at"] is None
    with pytest.raises(AppError):
        await repo.detail(outsider, household, item_id)


async def test_inventory_activity_failure_rolls_back_real_transaction(database):
    _, member, _, household = seed(database)
    as_actor(database, member, "homecircle_api")
    item_id = insert_item(database, household, member)
    database.execute("RESET ROLE")
    database.execute(
        "CREATE FUNCTION pg_temp.reject_inventory_event() RETURNS trigger "
        "LANGUAGE plpgsql AS $$ BEGIN RAISE check_violation "
        "USING MESSAGE='Injected event failure'; END $$"
    )
    database.execute(
        "CREATE TRIGGER inventory_test_event_failure BEFORE INSERT ON public.inventory_activity "
        "FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_inventory_event()"
    )
    with pytest.raises(psycopg.errors.CheckViolation):
        await InventoryService(FixtureRepository(database)).quantity(
            AuthenticatedUser(member, None),
            household,
            item_id,
            InventoryQuantityUpdate(operation="increase", amount="1"),
        )
    database.execute("RESET ROLE")
    row = database.execute(
        "SELECT quantity,revision FROM public.inventory_items WHERE id=%s", (item_id,)
    ).fetchone()
    assert row["quantity"] == Decimal("3") and row["revision"] == 1
    assert not database.execute(
        "SELECT id FROM public.inventory_activity WHERE inventory_item_id=%s", (item_id,)
    ).fetchall()


def test_inventory_storage_policies_and_revocation(database):
    admin, member, outsider, household = seed(database)
    as_actor(database, member, "homecircle_api")
    item_id = insert_item(database, household, member)
    path = f"{household}/{item_id}/{uuid4()}.jpg"
    database.execute(
        "INSERT INTO private.inventory_uploads(path,household_id,actor_id) VALUES(%s,%s,%s)",
        (path, household, member),
    )
    as_actor(database, member)
    assert database.execute(
        "SELECT private.inventory_upload_allowed(%s) AS ok", (path,)
    ).fetchone()["ok"]
    assert not database.execute(
        "SELECT private.inventory_photo_read(%s) AS ok", (path,)
    ).fetchone()["ok"]
    # Metadata-only fixtures verify actual Storage INSERT/SELECT/DELETE RLS; real
    # byte transfers also require the separate test project's Auth/Storage service.
    database.execute(
        "INSERT INTO storage.objects(bucket_id,name) VALUES('inventory-photos',%s)", (path,)
    )
    as_actor(database, member, "homecircle_api")
    database.execute("UPDATE public.inventory_items SET photo_path=%s WHERE id=%s", (path, item_id))
    as_actor(database, member)
    assert database.execute("SELECT private.inventory_photo_read(%s) AS ok", (path,)).fetchone()[
        "ok"
    ]
    assert not database.execute(
        "DELETE FROM storage.objects WHERE name=%s RETURNING id", (path,)
    ).fetchone()
    as_actor(database, outsider)
    assert not database.execute(
        "SELECT name FROM storage.objects WHERE name=%s", (path,)
    ).fetchall()
    as_actor(database, admin)
    database.execute("SELECT public.remove_household_member(%s,%s)", (household, member))
    as_actor(database, member)
    assert not database.execute(
        "SELECT private.inventory_photo_read(%s) AS ok", (path,)
    ).fetchone()["ok"]
    assert not database.execute(
        "SELECT private.inventory_upload_allowed(%s) AS ok", (path,)
    ).fetchone()["ok"]


@pytest.mark.parametrize("operation", ["increase", "set"])
def test_inventory_concurrent_quantity_updates(database, operation):
    # Invoking database validates the disposable test target before committed writes.
    tls = {"sslmode": "verify-full", "connect_timeout": 10}
    if cert := os.getenv("SUPABASE_TEST_DATABASE_SSLROOTCERT"):
        tls["sslrootcert"] = cert
    url = os.environ["SUPABASE_TEST_DATABASE_URL"]
    household, actors = None, []
    try:
        with psycopg.connect(url, row_factory=dict_row, **tls) as seed_connection:
            admin, member, outsider, household = seed(seed_connection)
            actors = [admin, member, outsider]
            as_actor(seed_connection, member, "homecircle_api")
            item_id = insert_item(seed_connection, household, member)
        barrier = Barrier(2, timeout=20)

        def worker(_):
            with psycopg.connect(url, row_factory=dict_row, **tls) as c:
                barrier.wait()
                data = InventoryQuantityUpdate(
                    operation=operation,
                    amount="1",
                    expected_revision=1 if operation == "set" else None,
                )

                async def run():
                    try:
                        await InventoryService(FixtureRepository(c)).quantity(
                            AuthenticatedUser(member, None), household, item_id, data
                        )
                        return "ok"
                    except AppError as error:
                        return error.code

                return asyncio.run(run())

        with ThreadPoolExecutor(max_workers=2) as workers:
            results = sorted(workers.map(worker, range(2)))
        assert results == (["ok", "ok"] if operation == "increase" else ["ok", "revision_conflict"])
        with psycopg.connect(url, row_factory=dict_row, **tls) as check:
            row = check.execute(
                "SELECT quantity,revision FROM public.inventory_items WHERE id=%s", (item_id,)
            ).fetchone()
            assert row["quantity"] == Decimal("5" if operation == "increase" else "1")
            assert row["revision"] == (3 if operation == "increase" else 2)
            assert check.execute(
                "SELECT count(*) AS n FROM public.inventory_activity WHERE inventory_item_id=%s",
                (item_id,),
            ).fetchone()["n"] == (2 if operation == "increase" else 1)
    finally:
        with psycopg.connect(url, **tls) as cleanup:
            if household:
                cleanup.execute("DELETE FROM public.households WHERE id=%s", (household,))
            for actor in actors:
                cleanup.execute("DELETE FROM auth.users WHERE id=%s", (actor,))
