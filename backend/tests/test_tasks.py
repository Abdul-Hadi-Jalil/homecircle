import asyncio
import base64
import copy
import json
from contextlib import asynccontextmanager
from datetime import UTC, datetime
from unittest.mock import AsyncMock
from uuid import uuid4

import httpx
import pytest
from psycopg.errors import ForeignKeyViolation
from pydantic import ValidationError

from app.api.v1.tasks import get_task_photos, get_task_service
from app.core.exceptions import AppError
from app.core.photo_body_limit import PhotoBodyLimit
from app.models.auth import AuthenticatedUser
from app.schemas.task import (
    Assignment,
    AttachmentUpload,
    CommentCreate,
    PriorityUpdate,
    StatusUpdate,
    TaskCreate,
    TaskUpdate,
)
from app.services.task_photos import TaskPhotos
from app.services.tasks import TaskService
from tests.test_inventory import photo_bytes

HOME, TASK, ACTOR, SECOND = uuid4(), uuid4(), uuid4(), uuid4()
USER = AuthenticatedUser(ACTOR, None)


def task_row(**fields):
    now = datetime.now(UTC)
    return {
        "id": TASK,
        "household_id": HOME,
        "task_type": "repair",
        "title": "Tap leak",
        "description": "Bathroom tap",
        "priority": "urgent",
        "status": "open",
        "created_by": ACTOR,
        "assigned_to": None,
        "updated_by": ACTOR,
        "due_date": None,
        "location": "Bathroom",
        "linked_inventory_item_id": None,
        "completion_note": None,
        "completed_at": None,
        "cancelled_at": None,
        "revision": 1,
        "created_at": now,
        "updated_at": now,
        "deleted_at": None,
        **fields,
    }


class Result:
    def __init__(self, row):
        self.row = row

    async def fetchone(self):
        return self.row


class FakeTasks:
    def __init__(self, row=None):
        self.row = row or task_row()
        self.events, self.comments_data, self.attachments_data, self.queries = [], {}, {}, []
        self.admin = False
        self.fail_event = False
        self.lock = asyncio.Lock()

    @asynccontextmanager
    async def transaction(self, actor, household):
        async with self.lock:
            if household != HOME:
                raise AppError(404, "not_found", "Household not found")
            before = copy.deepcopy(
                (self.row, self.events, self.comments_data, self.attachments_data)
            )
            try:
                yield self
            except Exception:
                self.row, self.events, self.comments_data, self.attachments_data = before
                raise

    async def task(self, c, household, task_id, **kwargs):
        if (
            household != HOME
            or task_id != TASK
            or (self.row["deleted_at"] and not kwargs.get("archived"))
        ):
            raise AppError(404, "not_found", "Task not found")
        return self.row.copy()

    async def create(self, actor, household, fields):
        self.row = task_row(**fields, created_by=actor, updated_by=actor)
        return self.row.copy()

    async def write(self, c, actor, household, task_id, fields):
        self.row.update(fields)
        self.row["updated_by"] = actor
        self.row["revision"] += 1
        return self.row.copy()

    async def event(self, c, actor, household, task_id, action, changes):
        if self.fail_event:
            raise RuntimeError("event insert failed")
        self.events.append({"actor": actor, "action": action, "changes": changes})

    async def is_admin(self, c, household):
        return self.admin

    async def insert(self, c, table, fields):
        row = {
            "id": uuid4(),
            "revision": 1,
            "created_at": datetime.now(UTC),
            "updated_at": datetime.now(UTC),
            "deleted_at": None,
            **fields,
        }
        (self.comments_data if table == "task_comments" else self.attachments_data)[row["id"]] = row
        return row.copy()

    async def comment(self, c, household, task_id, comment_id):
        row = self.comments_data.get(comment_id)
        if (
            not row
            or row["deleted_at"]
            or row["household_id"] != household
            or row["task_id"] != task_id
        ):
            raise AppError(404, "not_found", "Comment not found")
        return row.copy()

    async def attachment(self, c, household, task_id, attachment_id):
        row = self.attachments_data.get(attachment_id)
        if not row or row["household_id"] != household or row["task_id"] != task_id:
            raise AppError(404, "not_found", "Photo not found")
        return row.copy()

    async def execute(self, query, args=None):
        self.queries.append((query, args))
        if "count(*)" in query:
            return Result({"n": 0})
        if "UPDATE public.task_comments" in query:
            row = self.comments_data[args[-1]]
            row["deleted_at" if "SET deleted_at" in query else "body"] = args[0]
            row["revision"] += 1
            return Result(row.copy())
        return Result(None)


@pytest.mark.parametrize("kind", ["repair", "chore", "general"])
async def test_task_creation_and_defaults(kind):
    repository = FakeTasks()
    result = await TaskService(repository).create(
        USER, HOME, TaskCreate(title=" Clean ", task_type=kind)
    )
    assert result["task_type"] == kind and result["title"] == "Clean"
    assert result["priority"] == "normal" and result["created_by"] == ACTOR


@pytest.mark.parametrize(
    "fields",
    [
        {"task_type": "shopping"},
        {"priority": "critical"},
        {"title": " "},
        {"created_by": str(SECOND)},
        {"status": "completed"},
        {"task_type": "chore", "linked_inventory_item_id": str(uuid4())},
    ],
)
def test_task_input_cannot_forge_system_fields_or_shopping(fields):
    with pytest.raises(ValidationError):
        TaskCreate.model_validate({"title": "Request", **fields})


@pytest.mark.parametrize("source", ["open", "in_progress", "blocked"])
@pytest.mark.parametrize("target", ["open", "in_progress", "blocked", "completed", "cancelled"])
async def test_active_status_matrix(source, target):
    repository = FakeTasks(task_row(status=source))
    result = await TaskService(repository).status(
        USER, HOME, TASK, StatusUpdate(expected_revision=1, status=target)
    )
    assert result["status"] == target
    assert (result["completed_at"] is not None) == (target == "completed")
    assert (result["cancelled_at"] is not None) == (target == "cancelled")
    assert result["revision"] == (1 if source == target else 2)


@pytest.mark.parametrize("source", ["completed", "cancelled"])
async def test_terminal_reopen_is_explicit_and_keeps_historical_events(source):
    repository = FakeTasks()
    service = TaskService(repository)
    await service.status(
        USER,
        HOME,
        TASK,
        StatusUpdate(
            expected_revision=1,
            status=source,
            completion_note="Replaced washer" if source == "completed" else None,
        ),
    )
    for status in [
        "open",
        "in_progress",
        "blocked",
        "cancelled" if source == "completed" else "completed",
    ]:
        with pytest.raises(AppError) as error:
            await service.status(USER, HOME, TASK, StatusUpdate(expected_revision=2, status=status))
        assert error.value.status == 409
    reopened = await service.status(
        USER, HOME, TASK, StatusUpdate(expected_revision=2, status="open", reopen=True)
    )
    assert reopened["completed_at"] is None and reopened["cancelled_at"] is None
    assert reopened["completion_note"] is None
    assert [event["action"] for event in repository.events] == [source, "reopened"]
    if source == "completed":
        assert repository.events[-1]["changes"]["completion_note"]["before"] == "Replaced washer"


async def test_completion_never_updates_inventory_and_invalid_transitions_fail():
    repository = FakeTasks(task_row(linked_inventory_item_id=uuid4()))
    service = TaskService(repository)
    with pytest.raises(AppError):
        await service.status(
            USER, HOME, TASK, StatusUpdate(expected_revision=1, status="in_progress", reopen=True)
        )
    with pytest.raises(AppError):
        await service.status(
            USER,
            HOME,
            TASK,
            StatusUpdate(expected_revision=1, status="open", completion_note="Invalid"),
        )
    await service.status(USER, HOME, TASK, StatusUpdate(expected_revision=1, status="completed"))
    assert repository.queries == []


async def test_atomic_claims_have_one_winner_and_stale_edits_conflict():
    repository = FakeTasks()
    service = TaskService(repository)
    results = await asyncio.gather(
        *[
            service.assignment(
                AuthenticatedUser(actor, None),
                HOME,
                TASK,
                Assignment(operation="claim", expected_revision=1),
            )
            for actor in [ACTOR, SECOND]
        ],
        return_exceptions=True,
    )
    assert sum(isinstance(r, dict) for r in results) == 1
    assert sum(isinstance(r, AppError) and r.status == 409 for r in results) == 1
    assert repository.row["assigned_to"] in [ACTOR, SECOND]
    with pytest.raises(AppError) as error:
        await service.update(USER, HOME, TASK, TaskUpdate(title="stale", expected_revision=1))
    assert error.value.status == 409
    assert repository.events[0]["action"] == "claimed"


async def test_assignment_priority_and_archiving():
    repository = FakeTasks()
    service = TaskService(repository)
    await service.assignment(
        USER, HOME, TASK, Assignment(operation="assign", assigned_to=SECOND, expected_revision=1)
    )
    await service.assignment(
        USER, HOME, TASK, Assignment(operation="unassign", expected_revision=2)
    )
    await service.priority(USER, HOME, TASK, PriorityUpdate(priority="high", expected_revision=3))
    archived = await service.archive(USER, HOME, TASK, 4)
    assert archived["deleted_at"] is not None
    restored = await service.archive(USER, HOME, TASK, 5, restore=True)
    assert restored["deleted_at"] is None
    with pytest.raises(AppError):
        await service.priority(
            USER, uuid4(), TASK, PriorityUpdate(priority="low", expected_revision=6)
        )
    assert [e["action"] for e in repository.events] == [
        "assigned",
        "unassigned",
        "priority_changed",
        "archived",
        "restored",
    ]


async def test_comment_authorization_and_revisions():
    repository = FakeTasks()
    service = TaskService(repository)
    comment = await service.add_comment(
        USER, HOME, TASK, CommentCreate(expected_revision=1, body="On my way")
    )
    other = AuthenticatedUser(SECOND, None)
    with pytest.raises(AppError) as error:
        await service.change_comment(other, HOME, TASK, comment["id"], 2, 1, "Forged")
    assert error.value.status == 403
    assert repository.comments_data[comment["id"]]["body"] == "On my way"
    await service.change_comment(USER, HOME, TASK, comment["id"], 2, 1, "Fixed")
    repository.admin = True
    await service.change_comment(other, HOME, TASK, comment["id"], 3, 2)
    assert repository.comments_data[comment["id"]]["deleted_at"]
    assert [e["action"] for e in repository.events] == [
        "comment_added",
        "comment_edited",
        "comment_deleted",
    ]
    assert repository.events[-1]["actor"] == SECOND


async def test_failed_event_rolls_back_task_and_comment():
    repository = FakeTasks()
    repository.fail_event = True
    service = TaskService(repository)
    with pytest.raises(RuntimeError):
        await service.add_comment(USER, HOME, TASK, CommentCreate(expected_revision=1, body="Text"))
    assert repository.row["revision"] == 1 and repository.comments_data == {}
    with pytest.raises(RuntimeError):
        await service.priority(
            USER, HOME, TASK, PriorityUpdate(expected_revision=1, priority="low")
        )
    assert repository.row["priority"] == "urgent" and repository.row["revision"] == 1


async def test_invalid_reference_has_safe_error():
    repository = AsyncMock()
    repository.create.side_effect = ForeignKeyViolation("private details")
    with pytest.raises(AppError) as error:
        await TaskService(repository).create(
            USER, HOME, TaskCreate(title="Test", assigned_to=SECOND)
        )
    assert error.value.status == 422 and "private details" not in error.value.message


@pytest.mark.parametrize(
    ("method", "suffix", "body", "handler"),
    [
        ("POST", "", {"title": "Leak", "task_type": "repair"}, "create"),
        ("GET", f"/{TASK}", None, "detail"),
        ("PATCH", f"/{TASK}", {"title": "Updated", "expected_revision": 1}, "update"),
        (
            "PATCH",
            f"/{TASK}/assignment",
            {"operation": "claim", "expected_revision": 1},
            "assignment",
        ),
        ("PATCH", f"/{TASK}/priority", {"priority": "high", "expected_revision": 1}, "priority"),
        ("PATCH", f"/{TASK}/status", {"status": "completed", "expected_revision": 1}, "status"),
        ("DELETE", f"/{TASK}?expected_revision=1", None, "archive"),
        ("POST", f"/{TASK}/restore", {"expected_revision": 1}, "archive"),
    ],
)
def test_task_api_dispatch_and_verified_actor(client, method, suffix, body, handler):
    service = AsyncMock()
    getattr(service, handler).return_value = task_row()
    client.app.dependency_overrides[get_task_service] = lambda: service
    response = client.request(
        method,
        f"/api/v1/households/{HOME}/tasks{suffix}",
        headers={"Authorization": "Bearer valid-token"},
        **({"json": body} if body else {}),
    )
    assert response.status_code == (201 if method == "POST" and suffix == "" else 200), (
        response.text
    )
    assert response.json()["title"] == "Tap leak"
    assert getattr(service, handler).call_args.args[0].id is not None


def test_list_filters_summary_related_and_input_validation(client):
    service = AsyncMock()
    empty = {"items": [], "total": 0, "page": 1, "page_size": 20}
    service.list.return_value = service.related.return_value = empty
    service.summary.return_value = {"open": 1, "in_progress": 2, "completed": 3}
    client.app.dependency_overrides[get_task_service] = lambda: service
    root = f"/api/v1/households/{HOME}/tasks"
    headers = {"Authorization": "Bearer valid-token"}
    assert client.get(root).status_code == 401
    assert (
        client.get(
            root + "?priority=urgent&assignment=me&overdue=true&search=leak", headers=headers
        ).status_code
        == 200
    )
    filters = service.list.call_args.args[2]
    assert filters["priority"] == "urgent" and filters["overdue"] and filters["assignment"] == "me"
    assert client.get(root + "/summary", headers=headers).json()["open"] == 1
    assert (
        client.get(
            f"/api/v1/households/{HOME}/inventory/{uuid4()}/tasks", headers=headers
        ).status_code
        == 200
    )
    for query in [
        "sort=drop_table",
        "page_size=1000",
        "priority=critical",
        "due_before=not-a-date",
    ]:
        assert client.get(root + "?" + query, headers=headers).status_code == 422
    assert (
        client.patch(
            root + f"/{TASK}/status", headers=headers, json={"status": "completed"}
        ).status_code
        == 422
    )
    assert (
        client.post(
            root, headers=headers, json={"title": "Buy food", "task_type": "shopping"}
        ).status_code
        == 422
    )


async def test_private_signed_url_is_short_lived_and_user_authorized(settings):
    attachment_id = uuid4()
    repository = FakeTasks()
    repository.attachments_data[attachment_id] = {
        "id": attachment_id,
        "household_id": HOME,
        "task_id": TASK,
        "comment_id": None,
        "uploaded_by": ACTOR,
        "storage_path": f"{HOME}/{TASK}/{attachment_id}.jpg",
    }
    requests = []

    async def respond(request):
        requests.append(request)
        return httpx.Response(
            200,
            json={
                "signedURL": f"/object/sign/repair-attachments/{HOME}/{TASK}/"
                f"{attachment_id}.jpg?token=short-lived"
            },
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(respond)) as client:
        result = await TaskPhotos(repository, settings, client).read_url(
            USER, HOME, TASK, attachment_id, "Bearer verified-user"
        )
    assert result["expires_in"] == 60 and result["url"].startswith(settings.supabase_url)
    assert json.loads(requests[0].content) == {"expiresIn": 60}
    assert requests[0].headers["Authorization"] == "Bearer verified-user"
    with pytest.raises(AppError):
        await TaskPhotos(repository, settings).read_url(
            USER, uuid4(), TASK, attachment_id, "Bearer verified-user"
        )


def test_attachment_url_response_is_not_cacheable(client):
    photos = AsyncMock()
    photos.read_url.return_value = {"url": "https://test.supabase.co/file", "expires_in": 60}
    client.app.dependency_overrides[get_task_photos] = lambda: photos
    result = client.get(
        f"/api/v1/households/{HOME}/tasks/{TASK}/attachments/{uuid4()}/url",
        headers={"Authorization": "Bearer valid-token"},
    )
    assert result.status_code == 200 and result.headers["cache-control"] == "no-store"


@pytest.mark.parametrize("chunks", [[b"a" * 4, b"b" * 4], [b"a" * 5, b"b" * 5, b"c"]])
async def test_photo_body_limit_covers_chunked_requests(chunks):
    calls = []
    sent = []
    messages = iter(
        [
            {"type": "http.request", "body": chunk, "more_body": i < len(chunks) - 1}
            for i, chunk in enumerate(chunks)
        ]
    )

    async def receive():
        return next(messages)

    async def send(value):
        sent.append(value)

    async def app(scope, receive, send):
        body = b""
        while True:
            message = await receive()
            body += message.get("body", b"")
            if not message.get("more_body"):
                break
        calls.append(body)

    await PhotoBodyLimit(app, max_bytes=10)(
        {"type": "http", "path": "/api/v1/households/x/tasks/y/attachments", "method": "POST"},
        receive,
        send,
    )
    if sum(map(len, chunks)) > 10:
        assert not calls and sent[0]["status"] == 413
    else:
        assert calls == [b"".join(chunks)]


async def test_task_and_comment_photo_upload_remove_and_rollback(settings):
    repository = FakeTasks()
    service = TaskService(repository)
    comment = await service.add_comment(
        USER, HOME, TASK, CommentCreate(expected_revision=1, body="Photo follows")
    )
    requests = []

    async def respond(request):
        requests.append(request)
        return httpx.Response(200, json={})

    async with httpx.AsyncClient(transport=httpx.MockTransport(respond)) as client:
        photos = TaskPhotos(repository, settings, client)
        data = AttachmentUpload(
            expected_revision=2,
            comment_id=comment["id"],
            data_base64=base64.b64encode(photo_bytes()).decode(),
        )
        attachment = await photos.upload(USER, HOME, TASK, data, "Bearer verified-user")
        assert (
            attachment["comment_id"] == comment["id"] and attachment["content_type"] == "image/jpeg"
        )
        assert requests[0].headers["x-upsert"] == "false" and requests[0].content.startswith(
            b"\xff\xd8"
        )
        await photos.remove(USER, HOME, TASK, attachment["id"], 3, "Bearer verified-user")
        assert requests[-1].method == "DELETE" and repository.row["revision"] == 4
        assert [e["action"] for e in repository.events][-2:] == [
            "attachment_added",
            "attachment_removed",
        ]
        repository.fail_event = True
        with pytest.raises(RuntimeError):
            await photos.upload(
                USER,
                HOME,
                TASK,
                AttachmentUpload(expected_revision=4, data_base64=data.data_base64),
                "Bearer verified-user",
            )
        assert repository.row["revision"] == 4 and len(repository.attachments_data) == 1


async def test_comment_photo_requires_author_or_admin_before_storage_call(settings):
    repository = FakeTasks()
    comment_id = uuid4()
    repository.comments_data[comment_id] = {
        "id": comment_id,
        "household_id": HOME,
        "task_id": TASK,
        "author_user_id": SECOND,
        "deleted_at": None,
    }
    photos = TaskPhotos(repository, settings)
    photos.storage = AsyncMock()
    with pytest.raises(AppError) as error:
        await photos.upload(
            USER,
            HOME,
            TASK,
            AttachmentUpload(
                expected_revision=1,
                comment_id=comment_id,
                data_base64=base64.b64encode(photo_bytes()).decode(),
            ),
            "Bearer verified-user",
        )
    assert error.value.status == 403
    photos.storage.assert_not_called()


@pytest.mark.parametrize(
    ("method", "suffix", "body", "handler"),
    [
        ("GET", f"/{TASK}/comments", None, "comments"),
        ("POST", f"/{TASK}/comments", {"expected_revision": 1, "body": "On my way"}, "add_comment"),
        (
            "PATCH",
            f"/{TASK}/comments/{uuid4()}",
            {"expected_revision": 1, "expected_comment_revision": 1, "body": "Fixed"},
            "change_comment",
        ),
        (
            "DELETE",
            f"/{TASK}/comments/{uuid4()}?expected_revision=1&expected_comment_revision=1",
            None,
            "change_comment",
        ),
    ],
)
def test_comment_api_contract(client, method, suffix, body, handler):
    now = datetime.now(UTC)
    row = {
        "id": uuid4(),
        "household_id": HOME,
        "task_id": TASK,
        "author_user_id": ACTOR,
        "body": "Text",
        "revision": 1,
        "created_at": now,
        "updated_at": now,
        "deleted_at": None,
    }
    service = AsyncMock()
    getattr(service, handler).return_value = (
        {"items": [row], "page": 1, "page_size": 20} if handler == "comments" else row
    )
    client.app.dependency_overrides[get_task_service] = lambda: service
    result = client.request(
        method,
        f"/api/v1/households/{HOME}/tasks{suffix}",
        headers={"Authorization": "Bearer valid-token"},
        **({"json": body} if body else {}),
    )
    assert result.status_code == (201 if method == "POST" else 200), result.text
    assert getattr(service, handler).call_args.args[0].id is not None
