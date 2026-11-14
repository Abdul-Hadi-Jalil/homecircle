"""Chat SQL behavior. Uses only the existing guarded disposable hosted project."""

import asyncio
import os
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager
from threading import Barrier
from uuid import uuid4

import psycopg
import pytest
from psycopg.rows import dict_row

from app.core.exceptions import AppError
from app.models.auth import AuthenticatedUser
from app.repositories.chat import ChatRepository
from app.schemas.chat import MessageCreate, MessageEdit, TaskConversion
from app.services.chat import ChatService
from tests.test_chat import settings
from tests.test_database_integration import as_actor, create
from tests.test_database_integration import database as database  # noqa: F401
from tests.test_inventory_integration import FixtureRepository, seed

pytestmark = pytest.mark.integration


class FixtureChat(ChatRepository):
    pool = None

    def __init__(self, connection):
        self.connection = connection

    @asynccontextmanager
    async def transaction(self, actor, household):
        async with FixtureRepository.transaction(self, actor, household) as c:
            await c.execute(
                "SELECT pg_advisory_xact_lock(hashtextextended(%s,5))", (str(household),)
            )
            yield c


def service(connection):
    return ChatService(FixtureChat(connection), settings())


async def test_chat_members_outsiders_replies_edits_deletion_and_revocation(database):
    admin, member, outsider, home = seed(database)
    chat = service(database)
    actor = AuthenticatedUser(member, None)
    message, _ = await chat.send(
        actor, home, MessageCreate(client_message_id=uuid4(), body="Bring milk")
    )
    reply, _ = await chat.send(
        AuthenticatedUser(admin, None),
        home,
        MessageCreate(
            client_message_id=uuid4(), body="On my way", reply_to_message_id=message["id"]
        ),
    )
    edited = await chat.edit(
        actor, home, message["id"], MessageEdit(expected_revision=1, body="Milk and bread")
    )
    assert edited["revision"] == 2 and edited["edited_at"] is not None
    with pytest.raises(AppError):
        await chat.edit(
            AuthenticatedUser(admin, None),
            home,
            message["id"],
            MessageEdit(expected_revision=2, body="Wrong sender"),
        )
    with pytest.raises(AppError):
        await chat.detail(AuthenticatedUser(outsider, None), home, message["id"])
    await chat.delete(actor, home, message["id"], 2)
    deleted = await chat.detail(AuthenticatedUser(admin, None), home, message["id"])
    assert deleted["body"] is None and not deleted["attachments"]
    parent = await chat.detail(AuthenticatedUser(admin, None), home, reply["id"])
    assert parent["reply_preview"]["deleted"] and parent["reply_preview"]["body"] is None
    assert parent["version"] >= deleted["version"]
    database.execute("RESET ROLE")
    database.execute(
        "DELETE FROM public.household_members WHERE household_id=%s AND user_id=%s", (home, member)
    )
    with pytest.raises(AppError):
        await chat.detail(actor, home, reply["id"])
    as_actor(database, member)
    assert not database.execute(
        "SELECT private.chat_topic_allowed(%s) AS ok", (f"chat:{home}:{member}",)
    ).fetchone()["ok"]
    as_actor(database, admin, "homecircle_api")
    assert (
        database.execute(
            "SELECT sender_user_id FROM public.household_messages WHERE id=%s", (message["id"],)
        ).fetchone()["sender_user_id"]
        == member
    )


async def test_chat_cross_household_keys_and_direct_auth_write_denial(database):
    admin, member, outsider, home = seed(database)
    other = create(database, admin)
    chat = service(database)
    foreign, _ = await chat.send(
        AuthenticatedUser(admin, None),
        other,
        MessageCreate(client_message_id=uuid4(), body="Private second household"),
    )
    with pytest.raises(AppError):
        await chat.send(
            AuthenticatedUser(member, None),
            home,
            MessageCreate(
                client_message_id=uuid4(), body="Reply", reply_to_message_id=foreign["id"]
            ),
        )
    as_actor(database, member, "homecircle_api")
    with pytest.raises(psycopg.errors.ForeignKeyViolation), database.transaction():
        database.execute(
            "INSERT INTO public.household_messages(household_id,sender_user_id,"
            "client_message_id,message_type,body,reply_to_message_id,request_hash) VALUES(%s,"
            "%s,%s,'text','Wrong household',%s,'hash')",
            (home, member, uuid4(), foreign["id"]),
        )
    with (
        pytest.raises((psycopg.errors.CheckViolation, psycopg.errors.InsufficientPrivilege)),
        database.transaction(),
    ):
        database.execute(
            "INSERT INTO public.household_messages(household_id,sender_user_id,"
            "client_message_id,message_type,body,request_hash) VALUES(%s,%s,%s,'system',"
            "'Forged','hash')",
            (home, outsider, uuid4()),
        )
    as_actor(database, member)
    for query in [
        "SELECT body FROM public.household_messages",
        "INSERT INTO public.household_messages(household_id,sender_user_id,client_message_id,"
        "message_type,body,request_hash) VALUES(%s,%s,%s,'text','Direct','hash')",
    ]:
        with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
            database.execute(query, (home, member, uuid4()) if query.startswith("INSERT") else None)


async def test_chat_pagination_reactions_and_outbox_rollback(database):
    _, member, _, home = seed(database)
    chat = service(database)
    actor = AuthenticatedUser(member, None)
    created = []
    for text in ["One", "Two", "Three"]:
        row, _ = await chat.send(actor, home, MessageCreate(client_message_id=uuid4(), body=text))
        created.append(row)
    page = await chat.repository.listing(member, home, None, None, 2)
    assert [r["body"] for r in page["items"]] == ["Two", "Three"] and page["has_more"]
    older = await chat.repository.listing(member, home, page["older_cursor"], None, 2)
    assert [r["body"] for r in older["items"]] == ["One"]
    for _ in range(2):
        await chat.react(actor, home, created[0]["id"], "👍")
    result = await chat.detail(actor, home, created[0]["id"])
    assert result["reactions"] == [{"emoji": "👍", "count": 1, "mine": True}]
    await chat.react(actor, home, created[0]["id"], "👍", True)
    after = await chat.repository.changes(member, home, page["watermark"], 100)
    assert after["after"] > page["watermark"]
    before = database.execute(
        "SELECT count(*) AS n FROM public.chat_events WHERE household_id=%s", (home,)
    ).fetchone()["n"]
    original = chat.repository.insert

    async def fail(c, table, fields):
        result = await original(c, table, fields)
        if table == "household_messages":
            raise RuntimeError("Intentional post-insert failure")
        return result

    chat.repository.insert = fail
    with pytest.raises(RuntimeError):
        await chat.send(actor, home, MessageCreate(client_message_id=uuid4(), body="Rollback"))
    assert (
        database.execute(
            "SELECT count(*) AS n FROM public.chat_events WHERE household_id=%s", (home,)
        ).fetchone()["n"]
        == before
    )
    assert (
        database.execute(
            "SELECT count(*) AS n FROM public.household_messages WHERE household_id=%s", (home,)
        ).fetchone()["n"]
        == 3
    )


@pytest.mark.parametrize("kind", ["repair", "chore", "general", "shopping"])
async def test_chat_conversion_uses_existing_task_services_once(database, kind):
    _, member, _, home = seed(database)
    chat = service(database)
    actor = AuthenticatedUser(member, None)
    source, _ = await chat.send(
        actor, home, MessageCreate(client_message_id=uuid4(), body="Review this request")
    )
    data = TaskConversion(
        expected_revision=1,
        client_request_id=uuid4(),
        task_type=kind,
        fields={"title": "Reviewed task"},
    )
    first = await chat.convert(actor, home, source["id"], data)
    again = await chat.convert(actor, home, source["id"], data)
    assert first["id"] == again["id"] and first["task_type"] == kind
    database.execute("SET CONSTRAINTS ALL IMMEDIATE")
    assert (
        database.execute(
            "SELECT count(*) AS n FROM public.household_tasks WHERE household_id=%s", (home,)
        ).fetchone()["n"]
        == 1
    )
    assert (
        database.execute(
            "SELECT count(*) AS n FROM public.chat_task_conversions WHERE household_id=%s", (home,)
        ).fetchone()["n"]
        == 1
    )


def test_chat_image_binding_and_private_topic_authorization(database):
    _, member, outsider, home = seed(database)
    as_actor(database, member, "homecircle_api")
    mid, client, attachment = uuid4(), uuid4(), uuid4()
    path = f"{home}/{member}/{attachment}.jpg"
    database.execute(
        "INSERT INTO private.chat_uploads(id,household_id,actor_id,client_message_id,"
        "storage_path,input_hash,content_hash,size_bytes,finalized) VALUES(%s,%s,%s,%s,%s,%s,"
        "%s,10,true)",
        (attachment, home, member, client, path, "input", "normalized"),
    )
    database.execute(
        "INSERT INTO public.household_messages(id,household_id,sender_user_id,"
        "client_message_id,message_type,request_hash) VALUES(%s,%s,%s,%s,'image','hash')",
        (mid, home, member, client),
    )
    with pytest.raises(psycopg.errors.CheckViolation), database.transaction():
        database.execute("SET CONSTRAINTS ALL IMMEDIATE")
    database.execute(
        "INSERT INTO public.message_attachments(id,household_id,message_id,uploaded_by,"
        "storage_path,content_type,size_bytes) VALUES(%s,%s,%s,%s,%s,'image/jpeg',10)",
        (attachment, home, mid, member, path),
    )
    database.execute("SET CONSTRAINTS ALL IMMEDIATE")
    as_actor(database, member)
    assert database.execute("SELECT private.chat_photo_read(%s) AS ok", (path,)).fetchone()["ok"]
    assert database.execute(
        "SELECT private.chat_topic_allowed(%s) AS ok", (f"chat:{home}:{member}",)
    ).fetchone()["ok"]
    assert not database.execute(
        "SELECT private.chat_topic_allowed(%s) AS ok", (f"chat:{home}:{outsider}",)
    ).fetchone()["ok"]
    with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
        database.execute("SELECT public.dispatch_chat_outbox(100)")
    as_actor(database, outsider)
    assert not database.execute("SELECT private.chat_photo_read(%s) AS ok", (path,)).fetchone()[
        "ok"
    ]
    assert not database.execute(
        "SELECT private.chat_topic_allowed(%s) AS ok", (f"chat:{home}:{outsider}",)
    ).fetchone()["ok"]


@pytest.mark.parametrize("operation", ["send", "edit"])
def test_chat_concurrent_duplicate_send_and_stale_edit(database, operation):
    url = os.environ["SUPABASE_TEST_DATABASE_URL"]
    tls = {"sslmode": "verify-full", "connect_timeout": 10}
    if cert := os.getenv("SUPABASE_TEST_DATABASE_SSLROOTCERT"):
        tls["sslrootcert"] = cert
    home = None
    actors = []
    try:
        with psycopg.connect(url, row_factory=dict_row, **tls) as c:
            admin, member, outsider, home = seed(c)
            actors = [admin, member, outsider]
            client = uuid4()

            async def create_message():
                return await service(c).send(
                    AuthenticatedUser(member, None),
                    home,
                    MessageCreate(client_message_id=client, body="Original"),
                )

            original = asyncio.run(create_message())[0] if operation == "edit" else None
        barrier = Barrier(2, timeout=20)

        def worker(number):
            with psycopg.connect(url, row_factory=dict_row, **tls) as c:
                barrier.wait()

                async def run():
                    chat = service(c)
                    actor = AuthenticatedUser(member, None)
                    try:
                        if operation == "send":
                            row, new = await chat.send(
                                actor,
                                home,
                                MessageCreate(client_message_id=client, body="Original"),
                            )
                            return "created" if new else "reused"
                        await chat.edit(
                            actor,
                            home,
                            original["id"],
                            MessageEdit(expected_revision=1, body=f"Edit {number}"),
                        )
                        return "ok"
                    except AppError as error:
                        return error.code

                return asyncio.run(run())

        with ThreadPoolExecutor(max_workers=2) as pool:
            outcomes = sorted(pool.map(worker, [0, 1]))
        assert outcomes == (
            ["created", "reused"] if operation == "send" else ["ok", "revision_conflict"]
        )
        with psycopg.connect(url, row_factory=dict_row, **tls) as c:
            assert (
                c.execute(
                    "SELECT count(*) AS n FROM public.household_messages WHERE household_id=%s",
                    (home,),
                ).fetchone()["n"]
                == 1
            )
    finally:
        with psycopg.connect(url, **tls) as c:
            if home:
                c.execute("DELETE FROM public.households WHERE id=%s", (home,))
            for actor in actors:
                c.execute("DELETE FROM auth.users WHERE id=%s", (actor,))
