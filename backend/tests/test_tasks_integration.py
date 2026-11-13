"""Real SQL checks, exclusively through the guarded disposable hosted test fixture."""

import asyncio
import os
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from uuid import uuid4

import psycopg
import pytest
from psycopg.rows import dict_row

from app.core.exceptions import AppError
from app.models.auth import AuthenticatedUser
from app.repositories.tasks import TaskRepository
from app.schemas.inventory import InventoryConditionUpdate, InventoryItemCreate
from app.schemas.task import Assignment, CommentCreate, StatusUpdate, TaskCreate, TaskUpdate
from app.services.inventory import InventoryService
from app.services.tasks import TaskService
from tests.test_database_integration import as_actor
from tests.test_database_integration import database as database  # noqa: F401
from tests.test_inventory_integration import FixtureRepository, seed

pytestmark = pytest.mark.integration


class FixtureTasks(TaskRepository):
    def __init__(self, connection):
        self.connection = connection

    transaction = FixtureRepository.transaction


async def test_task_member_crud_filters_and_outsider_denial(database):
    _, member, outsider, home = seed(database)
    repository = FixtureTasks(database)
    service = TaskService(repository)
    actor = AuthenticatedUser(member, None)
    created = await service.create(
        actor, home, TaskCreate(title="Tap leak", task_type="repair", priority="urgent")
    )
    filters = {
        "search": "leak",
        "priority": "urgent",
        "assignment": "unassigned",
        "page": 1,
        "page_size": 20,
    }
    assert (await service.list(actor, home, filters))["items"][0]["id"] == created["id"]
    updated = await service.update(
        actor, home, created["id"], TaskUpdate(expected_revision=1, title="Fixed tap")
    )
    assert updated["revision"] == 2
    with pytest.raises(AppError) as error:
        await service.detail(AuthenticatedUser(outsider, None), home, created["id"])
    assert error.value.status == 404
    await service.archive(actor, home, created["id"], 2)
    assert not (await service.list(actor, home, {}))["items"]
    archived = await service.list(actor, home, {"archived": True})
    assert archived["items"][0]["id"] == created["id"]
    await service.archive(actor, home, created["id"], 3, restore=True)
    as_actor(database, member)
    with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
        database.execute(
            "INSERT INTO public.household_tasks(household_id,title,task_type) "
            "VALUES(%s,'Denied','general')",
            (home,),
        )


async def test_task_assignee_and_inventory_foreign_keys(database):
    _, member, outsider, home = seed(database)
    actor = AuthenticatedUser(member, None)
    service = TaskService(FixtureTasks(database))
    with pytest.raises(AppError) as error:
        await service.create(
            actor, home, TaskCreate(title="Invalid assignee", assigned_to=outsider)
        )
    assert error.value.status == 422
    other_service = TaskService(FixtureTasks(database))
    from tests.test_database_integration import create

    other = create(database, outsider)
    inventory = InventoryService(FixtureRepository(database))
    item = await inventory.create(
        AuthenticatedUser(outsider, None),
        other,
        InventoryItemCreate(name="Private machine", item_type="durable", condition="broken"),
    )
    with pytest.raises(AppError) as error:
        await other_service.create(
            actor,
            home,
            TaskCreate(title="Cross link", task_type="repair", linked_inventory_item_id=item["id"]),
        )
    assert error.value.status == 422


async def test_repair_completion_keeps_condition_until_separate_explicit_update(database):
    _, member, _, home = seed(database)
    actor = AuthenticatedUser(member, None)
    inventory = InventoryService(FixtureRepository(database))
    item = await inventory.create(
        actor, home, InventoryItemCreate(name="Tap", item_type="durable", condition="broken")
    )
    tasks = TaskService(FixtureTasks(database))
    task = await tasks.create(
        actor,
        home,
        TaskCreate(title="Repair tap", task_type="repair", linked_inventory_item_id=item["id"]),
    )
    await tasks.status(
        actor,
        home,
        task["id"],
        StatusUpdate(status="completed", expected_revision=1, completion_note="Replaced washer"),
    )
    assert (await inventory.repository.detail(member, home, item["id"]))["condition"] == "broken"
    await tasks.status(
        actor, home, task["id"], StatusUpdate(status="open", reopen=True, expected_revision=2)
    )
    events = await tasks.activity(actor, home, task["id"], 1, 20)
    assert {"completed", "reopened"} <= {event["action"] for event in events["items"]}
    await inventory.condition(
        actor, home, item["id"], InventoryConditionUpdate(condition="working", expected_revision=1)
    )
    assert (await inventory.repository.detail(member, home, item["id"]))["condition"] == "working"


async def test_task_comment_author_admin_boundaries_and_forged_actor_denial(database):
    admin, member, another, home = seed(database)
    database.execute("RESET ROLE")
    database.execute(
        "INSERT INTO public.household_members(household_id,user_id) VALUES(%s,%s)", (home, another)
    )
    service = TaskService(FixtureTasks(database))
    actor = AuthenticatedUser(member, None)
    task = await service.create(actor, home, TaskCreate(title="Discuss repair", task_type="repair"))
    comment = await service.add_comment(
        actor, home, task["id"], CommentCreate(expected_revision=1, body="On my way")
    )
    with pytest.raises(AppError) as error:
        await service.change_comment(
            AuthenticatedUser(another, None), home, task["id"], comment["id"], 2, 1, "Forged"
        )
    assert error.value.status == 403
    await service.change_comment(
        AuthenticatedUser(admin, None), home, task["id"], comment["id"], 2, 1, "Moderated"
    )
    as_actor(database, member, "homecircle_api")
    with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
        database.execute(
            "INSERT INTO public.task_activity(household_id,task_id,actor_user_id,action) "
            "VALUES(%s,%s,%s,'updated')",
            (home, task["id"], another),
        )


async def test_task_member_removal_unassigns_and_bumps_revision(database):
    admin, member, _, home = seed(database)
    service = TaskService(FixtureTasks(database))
    task = await service.create(
        AuthenticatedUser(admin, None),
        home,
        TaskCreate(title="Member chore", task_type="chore", assigned_to=member),
    )
    as_actor(database, admin)
    database.execute("SELECT public.remove_household_member(%s,%s)", (home, member))
    changed = await service.detail(AuthenticatedUser(admin, None), home, task["id"])
    assert changed["assigned_to"] is None and changed["revision"] == 2
    assert changed["updated_by"] == admin
    assert (await service.activity(AuthenticatedUser(admin, None), home, task["id"], 1, 20))[
        "items"
    ][0]["action"] == "unassigned"


async def test_task_activity_failure_rolls_back_database_write(database):
    _, member, _, home = seed(database)
    service = TaskService(FixtureTasks(database))
    actor = AuthenticatedUser(member, None)
    task = await service.create(actor, home, TaskCreate(title="Original"))
    database.execute("RESET ROLE")
    database.execute(
        "CREATE FUNCTION pg_temp.reject_task_event() RETURNS trigger LANGUAGE plpgsql AS $$ "
        "BEGIN RAISE check_violation USING MESSAGE='Injected event failure'; END $$"
    )
    database.execute(
        "CREATE TRIGGER task_test_event_failure BEFORE INSERT ON public.task_activity "
        "FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_task_event()"
    )
    with pytest.raises(psycopg.errors.CheckViolation):
        await service.update(
            actor, home, task["id"], TaskUpdate(expected_revision=1, title="Must roll back")
        )
    result = await service.detail(actor, home, task["id"])
    assert result["title"] == "Original" and result["revision"] == 1


async def test_task_private_attachment_policies_and_comment_scope(database):
    _, member, outsider, home = seed(database)
    actor = AuthenticatedUser(member, None)
    service = TaskService(FixtureTasks(database))
    task = await service.create(actor, home, TaskCreate(title="Photo repair", task_type="repair"))
    other = await service.create(actor, home, TaskCreate(title="Another task"))
    comment = await service.add_comment(
        actor, home, other["id"], CommentCreate(expected_revision=1, body="Other task")
    )
    as_actor(database, member, "homecircle_api")
    attachment = uuid4()
    path = f"{home}/{task['id']}/{attachment}.jpg"
    database.execute(
        "INSERT INTO private.task_uploads(path,household_id,actor_id) VALUES(%s,%s,%s)",
        (path, home, member),
    )
    as_actor(database, member)
    database.execute(
        "INSERT INTO storage.objects(bucket_id,name) VALUES('repair-attachments',%s)", (path,)
    )
    as_actor(database, member, "homecircle_api")
    args = (attachment, home, task["id"], member, path)
    insert = (
        "INSERT INTO public.task_attachments"
        "(id,household_id,task_id,uploaded_by,storage_path,content_type,size_bytes,comment_id) "
        "VALUES(%s,%s,%s,%s,%s,'image/jpeg',100,%s)"
    )
    with pytest.raises(psycopg.errors.ForeignKeyViolation), database.transaction():
        database.execute(insert, (*args, comment["id"]))
    database.execute(insert, (*args, None))
    database.execute("UPDATE private.task_uploads SET finalized=true WHERE path=%s", (path,))
    as_actor(database, member)
    assert database.execute("SELECT private.task_photo_read(%s) AS ok", (path,)).fetchone()["ok"]
    assert not database.execute(
        "DELETE FROM storage.objects WHERE name=%s RETURNING id", (path,)
    ).fetchone()
    as_actor(database, outsider)
    assert not database.execute(
        "SELECT name FROM storage.objects WHERE name=%s", (path,)
    ).fetchall()


@pytest.mark.parametrize("operation", ["claim", "edit"])
def test_concurrent_task_claims_and_updates(database, operation):
    # The fixture validates target identity before any committed records exist.
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

            async def create():
                return await TaskService(FixtureTasks(c)).create(
                    AuthenticatedUser(member, None), home, TaskCreate(title="Competing request")
                )

            task = asyncio.run(create())
        barrier = Barrier(2, timeout=20)

        def worker(actor):
            with psycopg.connect(url, row_factory=dict_row, **tls) as c:
                barrier.wait()

                async def run():
                    service = TaskService(FixtureTasks(c))
                    try:
                        if operation == "claim":
                            await service.assignment(
                                AuthenticatedUser(actor, None),
                                home,
                                task["id"],
                                Assignment(operation="claim", expected_revision=1),
                            )
                        else:
                            await service.update(
                                AuthenticatedUser(actor, None),
                                home,
                                task["id"],
                                TaskUpdate(title=str(actor), expected_revision=1),
                            )
                        return "ok"
                    except AppError as error:
                        return error.code

                return asyncio.run(run())

        with ThreadPoolExecutor(max_workers=2) as pool:
            results = sorted(pool.map(worker, [member, another]))
        assert results == ["ok", "revision_conflict"]
        with psycopg.connect(url, row_factory=dict_row, **tls) as c:
            row = c.execute(
                "SELECT revision,assigned_to FROM public.household_tasks WHERE id=%s", (task["id"],)
            ).fetchone()
            assert row["revision"] == 2
            if operation == "claim":
                assert row["assigned_to"] in [member, another]
    finally:
        with psycopg.connect(url, **tls) as c:
            if home:
                c.execute("DELETE FROM public.households WHERE id=%s", (home,))
            for actor in actors:
                c.execute("DELETE FROM auth.users WHERE id=%s", (actor,))
