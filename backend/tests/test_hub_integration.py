"""M6 behavior checks: only the existing explicitly guarded disposable hosted DB."""

from contextlib import asynccontextmanager
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from uuid import uuid4

import psycopg
import pytest

from app.core.exceptions import AppError
from app.models.auth import AuthenticatedUser
from app.repositories.hub import HubRepository
from app.schemas.chat import MessageCreate
from app.schemas.inventory import InventoryItemCreate, InventoryQuantityUpdate
from app.schemas.task import TaskCreate, TaskUpdate
from app.services.inventory import InventoryService
from app.services.tasks import TaskService
from tests.test_chat_integration import service as chat_service
from tests.test_database_integration import as_actor, create
from tests.test_database_integration import database as database  # noqa:F401
from tests.test_inventory_integration import AsyncConnectionAdapter, FixtureRepository, seed

pytestmark = pytest.mark.integration


class FixtureHub(HubRepository):
    pool = None

    def __init__(self, connection):
        self.connection = connection

    @asynccontextmanager
    async def transaction(self, actor, household):
        async with FixtureRepository.transaction(self, actor, household) as c:
            yield c

    @asynccontextmanager
    async def notification_transaction(self, actor, household=None):
        if household:
            async with self.transaction(actor, household) as c:
                yield c
        else:
            with self.connection.transaction():
                as_actor(self.connection, actor, "homecircle_api")
                yield AsyncConnectionAdapter(self.connection)


def tasks(c):
    from tests.test_tasks_integration import FixtureTasks

    return TaskService(FixtureTasks(c))


def inventory(c):
    return InventoryService(FixtureRepository(c))


def owner(c):
    c.execute("RESET ROLE")


def clear_notifications(c, home):
    owner(c)
    c.execute("DELETE FROM public.user_notifications WHERE household_id=%s", (home,))


async def add_task(c, actor, home, **fields):
    return await tasks(c).create(
        AuthenticatedUser(actor, None), home, TaskCreate(title="Request", **fields)
    )


async def add_stock(c, actor, home, quantity="3", minimum="1"):
    return await inventory(c).create(
        AuthenticatedUser(actor, None),
        home,
        InventoryItemCreate(
            name="Rice",
            item_type="consumable",
            quantity=quantity,
            unit="kg",
            minimum_quantity=minimum,
        ),
    )


async def test_hub_empty_membership_and_metrics_with_household_local_date(database):
    admin, member, outsider, home = seed(database)
    hub = FixtureHub(database)
    empty = await hub.dashboard(member, home)
    assert not empty["has_records"] and all(value == 0 for value in empty["summary"].values())
    with pytest.raises(AppError):
        await hub.dashboard(outsider, home)
    for index in range(4):
        await add_task(
            database,
            admin,
            home,
            priority="urgent" if index < 2 else "normal",
            assigned_to=member if index < 2 else None,
            due_date=datetime.now(UTC).date() - timedelta(days=1) if index == 0 else None,
        )
    for _ in range(6):
        owner(database)
        database.execute(
            "INSERT INTO public.household_tasks(household_id,title,task_type,created_by,"
            "updated_by) VALUES(%s,'Milk','shopping',%s,%s)",
            (home, admin, admin),
        )
        # M4 deferred parent/detail invariant is completed by its own migration trigger.
        identity = database.execute(
            "SELECT id FROM public.household_tasks WHERE household_id=%s AND title='Milk' "
            "ORDER BY created_at DESC LIMIT 1",
            (home,),
        ).fetchone()["id"]
        database.execute(
            "INSERT INTO public.shopping_item_details(household_id,task_id) VALUES(%s,%s)",
            (home, identity),
        )
    for _ in range(3):
        await add_stock(database, admin, home, "0.5")
    await add_stock(database, admin, home, "0")
    await add_stock(database, admin, home, "5")
    await inventory(database).create(
        AuthenticatedUser(admin, None),
        home,
        InventoryItemCreate(name="Washer", item_type="durable", condition="broken"),
    )
    result = await hub.dashboard(member, home)
    assert result["summary"] == dict(
        pending_tasks=4,
        urgent_issues=2,
        shopping_items=6,
        low_stock_items=3,
        out_of_stock_items=1,
        overdue_tasks=1,
        my_tasks=2,
    )
    attention = result["needs_attention"]
    assert [r["rank"] for r in attention] == sorted(r["rank"] for r in attention)
    assert len({(r["entity_type"], r["id"]) for r in attention}) == len(attention)
    assert result["household"]["id"] == str(home)
    await hub.zone(admin, home, "Pacific/Kiritimati")
    result = await hub.dashboard(member, home)
    expected = (datetime.now(UTC) + timedelta(hours=14)).date().isoformat()
    assert result["as_of_date"] == expected
    with pytest.raises(AppError):
        await hub.zone(member, home, "UTC")
    with pytest.raises(AppError):
        await hub.zone(admin, home, "Invalid/Zone")


async def test_hub_closed_archived_tasks_do_not_count_and_upcoming_is_bounded(database):
    admin, member, _, home = seed(database)
    today = datetime.now(UTC).date()
    for offset in [0, 1, 7, 8]:
        await add_task(database, admin, home, due_date=today + timedelta(days=offset))
    owner(database)
    for status in ["completed", "cancelled"]:
        database.execute(
            "INSERT INTO public.household_tasks(household_id,title,task_type,status,"
            "completed_at,cancelled_at,created_by,updated_by,due_date) VALUES(%s,'Closed',"
            "'general',%s,CASE WHEN %s='completed' THEN now() END,CASE WHEN %s='cancelled' "
            "THEN now() END,%s,%s,%s)",
            (home, status, status, status, admin, admin, today - timedelta(days=2)),
        )
    database.execute(
        "UPDATE public.household_tasks SET deleted_at=clock_timestamp() WHERE household_id=%s "
        "AND due_date=%s",
        (home, today + timedelta(days=8)),
    )
    data = await FixtureHub(database).dashboard(member, home)
    assert data["summary"]["pending_tasks"] == 3 and data["summary"]["overdue_tasks"] == 0
    assert len(data["upcoming_tasks"]) == 3


async def test_activity_projection_deduplicates_derived_audit_rows_and_paginates(database):
    admin, member, _, home = seed(database)
    task = await add_task(database, admin, home)
    await tasks(database).update(
        AuthenticatedUser(admin, None),
        home,
        task["id"],
        TaskUpdate(expected_revision=1, title="Renamed", assigned_to=member, priority="urgent"),
    )
    hub = FixtureHub(database)
    first = await hub.activity(member, home, "tasks", None, None, None, None, 1)
    second = await hub.activity(member, home, "tasks", None, None, None, first["cursor"], 1)
    assert (
        len(first["items"]) == len(second["items"]) == 1
        and first["items"][0]["id"] != second["items"][0]["id"]
    )
    assert (
        first["items"][0]["event_type"] == "updated"
        and second["items"][0]["event_type"] == "created"
    )
    assert first["items"][0]["actor_user_id"] == admin
    assert not second["has_more"]
    other = create(database, admin)
    with pytest.raises(AppError):
        await hub.activity(admin, other, "tasks", None, None, None, first["cursor"], 1)
    clear_notifications(database, home)
    before = database.execute(
        "SELECT count(*) AS n FROM public.household_activity_events WHERE household_id=%s", (home,)
    ).fetchone()["n"]
    await chat_service(database).send(
        AuthenticatedUser(member, None),
        home,
        MessageCreate(client_message_id=uuid4(), body="Private chat text"),
    )
    owner(database)
    assert (
        database.execute(
            "SELECT count(*) AS n FROM public.household_activity_events WHERE household_id=%s",
            (home,),
        ).fetchone()["n"]
        == before
    )


async def test_notification_assignment_preferences_own_action_suppression_and_recipient_rls(
    database,
):
    admin, member, outsider, home = seed(database)
    clear_notifications(database, home)
    await add_task(database, admin, home, assigned_to=member, priority="urgent")
    hub = FixtureHub(database)
    rows = (await hub.notifications(member, home, False, None, 30))["items"]
    assert len(rows) == 1 and rows[0]["event_type"] == "task_assigned"
    assert (await hub.unread(admin, home))["count"] == 0
    with pytest.raises(AppError):
        await hub.notifications(outsider, home, False, None, 30)
    await hub.notification(member, rows[0]["id"], "read")
    assert (await hub.unread(member, home))["count"] == 0
    with pytest.raises(AppError):
        await hub.notification(admin, rows[0]["id"], "dismiss")
    await hub.notification(member, rows[0]["id"], "dismiss")
    assert not (await hub.notifications(member, home, False, None, 30))["items"]
    await hub.preferences(member, home, {"tasks_enabled": False})
    await add_task(database, admin, home, assigned_to=member)
    assert not (await hub.notifications(member, home, False, None, 30))["items"]
    await hub.preferences(member, home, {"tasks_enabled": True})
    await add_task(database, member, home, assigned_to=member)
    assert (await hub.unread(member, home))["count"] == 0
    await add_task(database, admin, home, assigned_to=member)
    assert (await hub.read_all(member, home))["updated"] == 1
    as_actor(database, member, "homecircle_api")
    with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
        database.execute(
            "INSERT INTO public.user_notifications SELECT * FROM public.user_notifications LIMIT 1"
        )
    with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
        database.execute("SELECT token FROM public.user_device_tokens")
    with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
        database.execute("SELECT public.claim_notification_jobs(1)")


async def test_stock_transition_notifications_do_not_repeat_on_reads_or_low_to_low(database):
    admin, member, _, home = seed(database)
    clear_notifications(database, home)
    item = await add_stock(database, admin, home)
    service = inventory(database)
    actor = AuthenticatedUser(admin, None)
    for amount in ["1", "0.5", "0"]:
        await service.quantity(
            actor,
            home,
            item["id"],
            InventoryQuantityUpdate(
                operation="set", amount=Decimal(amount), expected_revision=item["revision"]
            ),
        )
        item = await service.repository.detail(admin, home, item["id"])
    hub = FixtureHub(database)
    for _ in range(2):
        await hub.dashboard(member, home)
    rows = (await hub.notifications(member, home, False, None, 30))["items"]
    assert len(rows) == 2 and all(r["event_type"] == "low_stock" for r in rows)


async def test_chat_mentions_are_explicit_scoped_private_and_idempotent(database):
    admin, member, outsider, home = seed(database)
    clear_notifications(database, home)
    hub = FixtureHub(database)
    await hub.preferences(member, home, {"chat_enabled": False, "mentions_enabled": True})
    data = MessageCreate(
        client_message_id=uuid4(), body="Private message", mentioned_user_ids=[member]
    )
    chat = chat_service(database)
    await chat.send(AuthenticatedUser(admin, None), home, data)
    await chat.send(AuthenticatedUser(admin, None), home, data)
    rows = (await hub.notifications(member, home, False, None, 30))["items"]
    assert len(rows) == 1 and rows[0]["event_type"] == "chat_mention"
    assert "Private message" not in rows[0]["body"]
    with pytest.raises(AppError):
        await chat.send(
            AuthenticatedUser(admin, None),
            home,
            MessageCreate(
                client_message_id=uuid4(), body="Foreign mention", mentioned_user_ids=[outsider]
            ),
        )


async def test_device_rotation_and_worker_leases_preferences_and_invalid_cleanup(database):
    admin, member, _, home = seed(database)
    clear_notifications(database, home)
    device = uuid4()
    as_actor(database, member, "homecircle_api")
    old = database.execute(
        "SELECT public.register_fcm_device(%s,%s,%s) AS id", ("a" * 22, device, "android")
    ).fetchone()["id"]
    current = database.execute(
        "SELECT public.register_fcm_device(%s,%s,%s) AS id", ("b" * 22, device, "android")
    ).fetchone()["id"]
    assert old != current
    assert (
        database.execute(
            "SELECT public.register_fcm_device(%s,%s,%s) AS id", ("b" * 22, device, "android")
        ).fetchone()["id"]
        == current
    )
    await add_task(database, admin, home, assigned_to=member)
    owner(database)
    database.execute("SET LOCAL ROLE homecircle_worker")
    job = database.execute("SELECT * FROM public.claim_notification_jobs(20)").fetchall()[0]
    assert database.execute("SELECT * FROM public.claim_notification_jobs(20)").fetchall() == []
    payload = database.execute(
        "SELECT public.authorize_notification_job(%s,%s) AS p", (job["job_id"], job["lease"])
    ).fetchone()["p"]
    assert set(payload) == {"token", "notification_id", "household_id", "event_type", "attempts"}
    assert payload["token"] == "b" * 22
    assert not database.execute(
        "SELECT public.finish_notification_job(%s,%s,%s,%s) AS ok",
        (job["job_id"], uuid4(), "sent", None),
    ).fetchone()["ok"]
    assert database.execute(
        "SELECT public.finish_notification_job(%s,%s,%s,%s) AS ok",
        (job["job_id"], job["lease"], "retry", "transient_fcm"),
    ).fetchone()["ok"]
    owner(database)
    state = database.execute(
        "SELECT * FROM private.notification_push_jobs WHERE id=%s", (job["job_id"],)
    ).fetchone()
    assert (
        state["state"] == "pending"
        and state["attempts"] == 1
        and state["next_retry_at"] > datetime.now(UTC)
    )
    database.execute(
        "UPDATE private.notification_push_jobs SET next_retry_at=clock_timestamp()-interval '1 "
        "second' WHERE id=%s",
        (job["job_id"],),
    )
    database.execute("SET LOCAL ROLE homecircle_worker")
    again = database.execute("SELECT * FROM public.claim_notification_jobs(20)").fetchone()
    database.execute(
        "SELECT public.finish_notification_job(%s,%s,%s,%s)",
        (again["job_id"], again["lease"], "invalid_token", "unregistered"),
    )
    owner(database)
    assert database.execute(
        "SELECT revoked_at FROM public.user_device_tokens WHERE id=%s", (current,)
    ).fetchone()["revoked_at"]


async def test_notification_jobs_recheck_preferences_and_membership_removal(database):
    admin, member, _, home = seed(database)
    clear_notifications(database, home)
    as_actor(database, member, "homecircle_api")
    database.execute(
        "SELECT public.register_fcm_device(%s,%s,%s)",
        ("target-12345678901234567890", uuid4(), "android"),
    )
    await add_task(database, admin, home, assigned_to=member)
    owner(database)
    database.execute("SET LOCAL ROLE homecircle_worker")
    job = database.execute("SELECT * FROM public.claim_notification_jobs(20)").fetchone()
    await FixtureHub(database).preferences(member, home, {"push_enabled": False})
    owner(database)
    database.execute("SET LOCAL ROLE homecircle_worker")
    assert (
        database.execute(
            "SELECT public.authorize_notification_job(%s,%s) AS p", (job["job_id"], job["lease"])
        ).fetchone()["p"]
        is None
    )
    owner(database)
    database.execute(
        "DELETE FROM public.household_members WHERE household_id=%s AND user_id=%s", (home, member)
    )
    assert (
        database.execute(
            "SELECT count(*) AS n FROM public.user_notifications WHERE household_id=%s AND "
            "recipient_user_id=%s",
            (home, member),
        ).fetchone()["n"]
        == 0
    )
    with pytest.raises(AppError):
        await FixtureHub(database).dashboard(member, home)


async def test_notification_projection_rolls_back_with_business_transaction(database):
    admin, member, _, home = seed(database)
    clear_notifications(database, home)
    before = database.execute(
        "SELECT count(*) AS n FROM public.household_activity_events WHERE household_id=%s", (home,)
    ).fetchone()["n"]
    with pytest.raises(RuntimeError), database.transaction():
        await add_task(database, admin, home, assigned_to=member)
        raise RuntimeError("Intentional rollback")
    owner(database)
    assert (
        database.execute(
            "SELECT count(*) AS n FROM public.household_activity_events WHERE household_id=%s",
            (home,),
        ).fetchone()["n"]
        == before
    )
    assert (
        database.execute(
            "SELECT count(*) AS n FROM public.user_notifications WHERE household_id=%s", (home,)
        ).fetchone()["n"]
        == 0
    )


def test_revoked_device_session_cannot_be_reactivated_by_late_registration(database):
    _, member, _, _ = seed(database)
    installation = uuid4()
    as_actor(database, member, "homecircle_api")
    database.execute(
        "SELECT public.register_fcm_device(%s,%s,%s)",
        ("target-1234567890123456", installation, "android"),
    )
    database.execute("SELECT public.revoke_fcm_device(%s)", (installation,))
    with pytest.raises(psycopg.errors.CheckViolation), database.transaction():
        database.execute(
            "SELECT public.register_fcm_device(%s,%s,%s)",
            ("target-1234567890123456", installation, "android"),
        )
    # A fresh sign-in creates a new installation session, allowing the target again.
    database.execute(
        "SELECT public.register_fcm_device(%s,%s,%s)",
        ("target-1234567890123456", uuid4(), "android"),
    )
