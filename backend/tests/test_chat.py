import asyncio
import base64
import copy
from contextlib import asynccontextmanager
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import uuid4

import httpx
import pytest
from pydantic import ValidationError

from app.api.v1.chat import get_chat
from app.core.exceptions import AppError
from app.models.auth import AuthenticatedUser
from app.repositories.chat import ChatRepository, cursor_for, parse_cursor
from app.schemas.chat import ChatUpload, MessageCreate, MessageEdit, Reaction, TaskConversion
from app.services.chat import ChatService
from app.services.chat_photos import ChatPhotos
from tests.test_inventory import photo_bytes
from tests.test_tasks import ACTOR, HOME, SECOND, TASK, USER, Result, task_row


def message_row(**fields):
    return {
        "id": uuid4(),
        "household_id": HOME,
        "sender_user_id": ACTOR,
        "client_message_id": uuid4(),
        "message_type": "text",
        "body": "Bring milk",
        "reply_to_message_id": None,
        "linked_task_id": None,
        "created_at": datetime.now(UTC),
        "updated_at": datetime.now(UTC),
        "edited_at": None,
        "deleted_at": None,
        "revision": 1,
        "version": 1,
        "request_hash": "hash",
        **fields,
    }


class FakeChat:
    pool = None

    def __init__(self):
        self.rows = {}
        self.uploads = {}
        self.reactions = set()
        self.conversions = {}
        self.events = []
        self.rates = {}
        self.lock = asyncio.Lock()
        self.fail_insert = False

    @asynccontextmanager
    async def transaction(self, actor, household):
        async with self.lock:
            if actor not in (ACTOR, SECOND) or household != HOME:
                raise AppError(404, "not_found", "Household not found")
            state = copy.deepcopy(
                (self.rows, self.uploads, self.reactions, self.conversions, self.events, self.rates)
            )
            try:
                yield self
            except Exception:
                (
                    self.rows,
                    self.uploads,
                    self.reactions,
                    self.conversions,
                    self.events,
                    self.rates,
                ) = state
                raise

    async def rate(self, c, actor, household, action, limit):
        key = (actor, action)
        self.rates[key] = self.rates.get(key, 0) + 1
        if self.rates[key] > limit:
            raise AppError(429, "rate_limited", "Too many actions")

    async def raw(self, c, household, message_id):
        row = self.rows.get(message_id)
        if not row or row["household_id"] != household:
            raise AppError(404, "not_found", "Message not found")
        return row.copy()

    async def by_client(self, c, actor, household, client_id):
        return next(
            (
                r.copy()
                for r in self.rows.values()
                if r["sender_user_id"] == actor
                and r["household_id"] == household
                and r["client_message_id"] == client_id
            ),
            None,
        )

    async def message(self, c, actor, household, message_id):
        row = await self.raw(c, household, message_id)
        return {
            **row,
            "body": None if row["deleted_at"] else row["body"],
            "sender_name": "Arham",
            "reactions": [
                {
                    "emoji": emoji,
                    "count": sum(
                        1 for mid, u, e in self.reactions if mid == message_id and e == emoji
                    ),
                    "mine": (message_id, actor, emoji) in self.reactions,
                }
                for emoji in {e for mid, u, e in self.reactions if mid == message_id}
            ],
            "attachments": [],
            "converted_tasks": [],
        }

    async def task_preview(self, c, household, task_id):
        return (
            task_row()
            if household == HOME and task_id == TASK
            else {"id": task_id, "household_id": household, "unavailable": True}
        )

    async def insert(self, c, table, fields):
        if self.fail_insert:
            raise RuntimeError("Intentional insert failure")
        if table == "household_messages":
            row = message_row(**fields)
            self.rows[row["id"]] = row
            self.events.append(("created", row["id"]))
            return row
        if table == "chat_task_conversions":
            self.conversions[fields["client_request_id"]] = fields
            self.events.append(("converted", fields["message_id"]))
            return fields
        return fields

    async def write_message(self, c, household, message_id, fields):
        row = self.rows[message_id]
        row.update(fields)
        row["revision"] += 1
        row["version"] += 1
        self.events.append(("updated", message_id))

    async def upload(self, c, household, identity, actor):
        row = self.uploads.get(identity)
        if not row or row["household_id"] != household or row["actor_id"] != actor:
            raise AppError(404, "not_found", "Image not found")
        return row

    async def execute(self, query, args=None):
        if "SELECT * FROM public.chat_task_conversions" in query:
            return Result(self.conversions.get(args[-1]))
        if "SELECT storage_path" in query:
            return Page([])
        if "INSERT INTO public.message_reactions" in query:
            self.reactions.add((args[1], args[2], args[3]))
            return Result(None)
        if "DELETE FROM public.message_reactions" in query:
            self.reactions.discard((args[1], args[2], args[3]))
            return Result(None)
        if "SELECT * FROM private.chat_uploads" in query:
            return Result(self.uploads.get(args[0]))
        if "SELECT id FROM private.chat_uploads" in query:
            return Result(self.uploads.get(args[0]))
        if "INSERT INTO private.chat_uploads" in query:
            identity, house, actor, client, path, input_hash, content_hash, size = args
            self.uploads[identity] = {
                "id": identity,
                "household_id": house,
                "actor_id": actor,
                "client_message_id": client,
                "storage_path": path,
                "input_hash": input_hash,
                "content_hash": content_hash,
                "size_bytes": size,
                "expires_at": datetime.now(UTC) + timedelta(minutes=1),
                "finalized": False,
                "abandoned": False,
            }
        if "UPDATE private.chat_uploads SET finalized=true,expires_at" in query:
            self.uploads[args[2]].update(finalized=True, expires_at=args[0])
        if "UPDATE private.chat_uploads SET finalized=true,abandoned=true" in query:
            for row in self.uploads.values():
                if row["storage_path"] == args[2]:
                    row.update(finalized=True, abandoned=True)
        return Result(None)


class Page(Result):
    async def fetchall(self):
        return self.row


def settings():
    return SimpleNamespace(
        chat_message_rate=60,
        chat_reaction_rate=120,
        chat_upload_rate=10,
        chat_image_max_bytes=5 * 1024 * 1024,
        supabase_publishable_key=None,
        supabase_url="https://project.supabase.co",
    )


def service():
    repo = FakeChat()
    return ChatService(repo, settings(), AsyncMock()), repo


@pytest.mark.parametrize(
    "data",
    [
        {"body": ""},
        {"body": "  "},
        {"body": None},
        {"body": "x" * 4001},
        {"body": "hi", "sender_user_id": str(SECOND)},
        {"message_type": "system", "body": "Admin event"},
        {"message_type": "image", "body": "missing photo"},
        {"message_type": "task_share", "body": "missing task"},
        {"message_type": "text", "body": "hi", "linked_task_id": str(TASK)},
    ],
)
def test_chat_rejects_empty_invalid_and_forged_messages(data):
    with pytest.raises(ValidationError):
        MessageCreate(client_message_id=uuid4(), **data)


async def test_concurrent_duplicate_submissions_persist_once_and_return_original():
    chat, repo = service()
    data = MessageCreate(client_message_id=uuid4(), body=" Milk ")
    results = await asyncio.gather(chat.send(USER, HOME, data), chat.send(USER, HOME, data))
    assert (
        len(repo.rows) == 1
        and len(repo.events) == 1
        and sorted(r[1] for r in results) == [False, True]
    )
    assert results[0][0]["id"] == results[1][0]["id"]
    assert results[0][0]["body"] == "Milk"
    with pytest.raises(AppError) as error:
        await chat.send(
            USER, HOME, MessageCreate(client_message_id=data.client_message_id, body="Different")
        )
    assert error.value.code == "idempotency_conflict"


async def test_sender_ownership_revisions_and_soft_delete():
    chat, repo = service()
    row, _ = await chat.send(USER, HOME, MessageCreate(client_message_id=uuid4(), body="Milk"))
    with pytest.raises(AppError) as error:
        await chat.edit(
            AuthenticatedUser(SECOND, None),
            HOME,
            row["id"],
            MessageEdit(expected_revision=1, body="Changed"),
        )
    assert error.value.status == 403
    updated = await chat.edit(USER, HOME, row["id"], MessageEdit(expected_revision=1, body="Bread"))
    assert updated["revision"] == 2 and updated["edited_at"] is not None
    with pytest.raises(AppError):
        await chat.delete(USER, HOME, row["id"], 1)
    deleted, _ = await chat.delete(USER, HOME, row["id"], 2)
    assert deleted["body"] is None and repo.rows[row["id"]]["body"] == "Bread"
    retry, _ = await chat.delete(USER, HOME, row["id"], 2)
    assert retry["revision"] == 3


async def test_foreign_reply_and_task_links_rollback_message_creation():
    chat, repo = service()
    for fields in [
        {"reply_to_message_id": uuid4()},
        {"message_type": "task_share", "linked_task_id": uuid4()},
    ]:
        with pytest.raises(AppError):
            await chat.send(
                USER, HOME, MessageCreate(client_message_id=uuid4(), body="Message", **fields)
            )
    assert not repo.rows and not repo.events
    with pytest.raises(AppError):
        await chat.send(
            AuthenticatedUser(uuid4(), None),
            HOME,
            MessageCreate(client_message_id=uuid4(), body="Denied"),
        )


async def test_replies_to_deleted_parents_and_reactions_are_idempotent():
    chat, repo = service()
    parent, _ = await chat.send(USER, HOME, MessageCreate(client_message_id=uuid4(), body="Milk"))
    await chat.delete(USER, HOME, parent["id"], 1)
    reply, _ = await chat.send(
        AuthenticatedUser(SECOND, None),
        HOME,
        MessageCreate(client_message_id=uuid4(), body="Reply", reply_to_message_id=parent["id"]),
    )
    for _ in range(2):
        await chat.react(USER, HOME, reply["id"], "👍")
    assert len(repo.reactions) == 1
    for _ in range(2):
        await chat.react(USER, HOME, reply["id"], "👍", True)
    assert not repo.reactions
    with pytest.raises(ValidationError):
        Reaction(emoji="unsupported")


async def test_persistent_rate_limit_blocks_spam_without_creating_messages():
    chat, repo = service()
    chat.settings.chat_message_rate = 2
    for _ in range(2):
        await chat.send(USER, HOME, MessageCreate(client_message_id=uuid4(), body="Hi"))
    with pytest.raises(AppError) as error:
        await chat.send(USER, HOME, MessageCreate(client_message_id=uuid4(), body="Spam"))
    assert error.value.status == 429 and len(repo.rows) == 2


def test_cursor_roundtrip_scope_and_malformed_boundaries():
    row = message_row()
    cursor = cursor_for(row)
    assert parse_cursor(cursor, HOME) == (row["created_at"], row["id"])
    for value in ["invalid", "a" * 400, cursor_for({**row, "household_id": uuid4()})]:
        with pytest.raises(AppError):
            parse_cursor(value, HOME)


async def test_deleted_message_response_redacts_content_and_private_relations():
    repo = ChatRepository(None)
    row = message_row(
        deleted_at=datetime.now(UTC), linked_task_id=TASK, reply_to_message_id=uuid4()
    )
    repo.raw = AsyncMock(return_value=row)
    c = SimpleNamespace(
        execute=AsyncMock(side_effect=[Result({"n": 4}), Result({"name": "Former"})])
    )
    result = await repo.message(c, ACTOR, HOME, row["id"])
    assert (
        result["body"] is None
        and result["linked_task_id"] is None
        and result["reply_to_message_id"] is None
    )
    assert not result["attachments"] and not result["reactions"] and "request_hash" not in result


@pytest.mark.parametrize("kind", ["repair", "chore", "general", "shopping"])
async def test_conversion_reuses_existing_services_and_retry_identity(monkeypatch, kind):
    chat, repo = service()
    row, _ = await chat.send(
        USER, HOME, MessageCreate(client_message_id=uuid4(), body="Please buy milk")
    )
    created = task_row(task_type=kind)
    factory = AsyncMock(return_value=created)
    monkeypatch.setattr(
        "app.services.chat.ShoppingService.detail"
        if kind == "shopping"
        else "app.services.chat.TaskService.detail",
        AsyncMock(return_value=created),
    )
    monkeypatch.setattr(
        "app.services.chat.ShoppingService.create"
        if kind == "shopping"
        else "app.services.chat.TaskService.create",
        factory,
    )
    data = TaskConversion(
        expected_revision=1,
        client_request_id=uuid4(),
        task_type=kind,
        fields={"title": "Reviewed request"},
    )
    first = await chat.convert(USER, HOME, row["id"], data)
    second = await chat.convert(USER, HOME, row["id"], data)
    assert first == second == created and factory.await_count == 1
    assert len(repo.conversions) == 1


async def test_secure_photo_upload_finalization_signing_and_user_token():
    repo = FakeChat()
    stored = {}
    calls = []

    async def handler(request):
        calls.append(request)
        if "/object/sign/" in request.url.path:
            return httpx.Response(
                200, json={"signedURL": "/object/sign/chat-attachments/file.jpg?token=short"}
            )
        if request.method == "POST":
            stored["bytes"] = request.content
        if request.method == "GET":
            return httpx.Response(200, content=stored["bytes"])
        return httpx.Response(200, json={})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        photos = ChatPhotos(repo, settings(), client)
        data = ChatUpload(
            client_message_id=uuid4(),
            attachment_id=uuid4(),
            data_base64=base64.b64encode(photo_bytes()).decode(),
        )
        result = await photos.upload_image(USER, HOME, data, "Bearer user-token")
        assert result["id"] == data.attachment_id and repo.uploads[data.attachment_id]["finalized"]
        assert stored["bytes"].startswith(b"\xff\xd8")
        await photos.verify(repo.uploads[data.attachment_id], "Bearer user-token")
        again = await photos.upload_image(USER, HOME, data, "Bearer user-token")
        assert again["id"] == result["id"] and sum(c.method == "POST" for c in calls) == 1
        assert all(c.headers["authorization"] == "Bearer user-token" for c in calls)
        assert calls[0].headers["x-upsert"] == "false"


def test_chat_api_auth_validation_status_codes_and_operations(client):
    chat = AsyncMock()
    chat.send.side_effect = [({"id": str(uuid4())}, True), ({"id": str(uuid4())}, False)]
    chat.repository.listing.return_value = {"items": [], "has_more": False}
    chat.repository.changes.return_value = {"items": [], "after": 0, "has_more": False}
    chat.detail.return_value = {"body": None}
    chat.edit.return_value = {"body": "Edited"}
    chat.delete.return_value = ({"body": None}, [])
    chat.react.return_value = {"reactions": []}
    chat.convert.return_value = {"id": str(TASK)}
    client.app.dependency_overrides[get_chat] = lambda: chat
    root = f"/api/v1/households/{HOME}/chat"
    headers = {"Authorization": "Bearer valid-token"}
    assert client.get(root + "/messages").status_code == 401
    for path in ["/messages", "/changes", f"/messages/{uuid4()}"]:
        assert client.get(root + path, headers=headers).status_code == 200
    payload = {"client_message_id": str(uuid4()), "body": "Hello"}
    assert client.post(root + "/messages", headers=headers, json=payload).status_code == 201
    assert client.post(root + "/messages", headers=headers, json=payload).status_code == 200
    assert (
        client.patch(
            root + f"/messages/{uuid4()}",
            headers=headers,
            json={"expected_revision": 1, "body": "Edit"},
        ).status_code
        == 200
    )
    assert (
        client.delete(
            root + f"/messages/{uuid4()}?expected_revision=1", headers=headers
        ).status_code
        == 200
    )
    assert (
        client.put(
            root + f"/messages/{uuid4()}/reactions", headers=headers, json={"emoji": "👍"}
        ).status_code
        == 200
    )
    assert (
        client.delete(
            root + f"/messages/{uuid4()}/reactions/%F0%9F%91%8D", headers=headers
        ).status_code
        == 200
    )
    for query in ["limit=1000", "before=abc&after=def"]:
        assert client.get(root + "/messages?" + query, headers=headers).status_code == 422
    assert (
        client.post(
            root + "/messages", headers=headers, json={**payload, "sender_user_id": str(SECOND)}
        ).status_code
        == 422
    )
