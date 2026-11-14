from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock
from uuid import UUID, uuid4

import pytest
from firebase_admin import exceptions, messaging
from google.auth.exceptions import DefaultCredentialsError
from pydantic import ValidationError

from app.api.v1.hub import get_hub
from app.core.exceptions import AppError
from app.repositories.hub import decode_cursor, encode_cursor
from app.schemas.chat import MessageCreate
from app.schemas.hub import Dashboard, DeviceRegistration, PreferencesPatch
from app.services.chat import digest
from app.services.hub import HubService
from app.workers.notifications import FirebaseSender, process_batch
from tests.conftest import USER_ID
from tests.test_chat import message_row
from tests.test_chat import service as chat_service
from tests.test_tasks import HOME as CHAT_HOME
from tests.test_tasks import USER as CHAT_USER

HOME = uuid4()
HEADERS = {"Authorization": "Bearer valid-token"}


def dashboard_data():
    return {
        "household": {"id": str(HOME), "name": "Home", "time_zone": "Asia/Karachi"},
        "summary": dict(
            pending_tasks=0,
            urgent_issues=0,
            shopping_items=0,
            low_stock_items=0,
            out_of_stock_items=0,
            overdue_tasks=0,
            my_tasks=0,
        ),
        "needs_attention": [],
        "upcoming_tasks": [],
        "recent_activity": [],
        "unread_notifications": 0,
        "has_records": False,
        "as_of_date": "2026-11-14",
        "refreshed_at": datetime.now(UTC).isoformat(),
    }


def notification_data():
    return dict(
        id=str(uuid4()),
        recipient_user_id=str(USER_ID),
        household_id=str(HOME),
        event_type="task_assigned",
        title="A request",
        body="Open HomeCircle",
        related_entity_type="task",
        related_entity_id=str(uuid4()),
        source_event_id=str(uuid4()),
        created_at=datetime.now(UTC).isoformat(),
        read_at=None,
        dismissed_at=None,
    )


def test_dashboard_contract_empty_and_typed_metrics():
    value = Dashboard.model_validate(dashboard_data())
    assert (
        not value.has_records
        and value.summary.pending_tasks == 0
        and value.household.time_zone == "Asia/Karachi"
    )
    bad = dashboard_data()
    bad["household"]["id"] = "not-a-uuid"
    with pytest.raises(ValidationError):
        Dashboard.model_validate(bad)


async def test_chat_mentions_preserve_legacy_retry_hash_and_validate_limits():
    data = MessageCreate(client_message_id=uuid4(), body="Existing send")
    previous = data.model_dump(exclude={"mentioned_user_ids"})
    chat, repository = chat_service()
    row = message_row(client_message_id=data.client_message_id, request_hash=digest(previous))
    repository.rows[row["id"]] = row
    result, created = await chat.send(CHAT_USER, CHAT_HOME, data)
    assert not created and result["id"] == row["id"]
    with pytest.raises(ValidationError):
        MessageCreate(
            client_message_id=uuid4(),
            body="Too many mentions",
            mentioned_user_ids=[uuid4() for _ in range(21)],
        )


@pytest.mark.parametrize(
    "data",
    [
        {"tasks_enabled": None},
        {"user_id": str(uuid4())},
        {"household_id": str(HOME)},
        {"unknown": True},
    ],
)
def test_preferences_reject_null_identity_and_unknown_fields(data):
    with pytest.raises(ValidationError):
        PreferencesPatch.model_validate(data)


def test_device_token_validation_and_safe_repr():
    data = DeviceRegistration(token="secret-target-123456789", device_identifier=uuid4())
    assert "secret-target" not in repr(data)
    for fields in [
        {"token": "short", "device_identifier": str(uuid4())},
        {"token": "x" * 20, "device_identifier": str(uuid4()), "user_id": str(uuid4())},
    ]:
        with pytest.raises(ValidationError):
            DeviceRegistration.model_validate(fields)


def test_hub_cursor_binds_identity_household_filter_and_dates():
    row = {"id": uuid4(), "created_at": datetime.now(UTC)}
    scope = [str(HOME), "repairs", "2026-11-14"]
    cursor = encode_cursor(row, scope)
    assert decode_cursor(cursor, scope) == (row["created_at"], row["id"])
    for value, binding in [
        (cursor, [str(uuid4()), "repairs", "2026-11-14"]),
        ("?", scope),
        ("a" * 400, scope),
    ]:
        with pytest.raises(AppError):
            decode_cursor(value, binding)


@pytest.mark.parametrize(
    "start,end",
    [
        (datetime(2026, 1, 1), None),
        (None, datetime(2026, 1, 1)),
        (datetime.now(UTC), datetime.now(UTC) - timedelta(days=1)),
    ],
)
async def test_activity_rejects_invalid_ranges_before_repository(start, end):
    repo = SimpleNamespace(activity=AsyncMock())
    with pytest.raises(AppError):
        await HubService(repo).activity(USER_ID, HOME, None, None, start, end, None, 30)
    repo.activity.assert_not_called()


def test_hub_api_auth_scope_state_and_preference_contracts(client):
    repo = AsyncMock()
    repo.dashboard.return_value = dashboard_data()
    repo.activity.return_value = {"items": [], "cursor": None, "has_more": False}
    repo.notifications.return_value = {"items": [], "cursor": None, "has_more": False}
    repo.unread.return_value = {"count": 0}
    repo.preferences.return_value = {"user_id": str(USER_ID), "household_id": str(HOME)}
    repo.register.return_value = {"id": str(uuid4())}
    repo.revoke.return_value = {"revoked": True}
    repo.read_all.return_value = {"updated": 2}
    row = notification_data()
    repo.notification.return_value = row
    client.app.dependency_overrides[get_hub] = lambda: HubService(repo)
    root = f"/api/v1/households/{HOME}"
    for path in [
        root + "/dashboard",
        root + "/activity",
        "/api/v1/notifications",
        "/api/v1/notifications/unread-count",
    ]:
        assert client.get(path).status_code == 401
        result = client.get(path, headers=HEADERS)
        assert result.status_code == 200 and result.headers["cache-control"] == "no-store"
    assert client.get(root + "/activity?page_size=101", headers=HEADERS).status_code == 422
    assert client.get(root + "/activity?category=private", headers=HEADERS).status_code == 422
    assert (
        client.patch(
            root + "/notification-preferences", headers=HEADERS, json={"chat_enabled": False}
        ).status_code
        == 200
    )
    repo.preferences.assert_awaited_with(USER_ID, HOME, {"chat_enabled": False})
    assert (
        client.patch(
            root + "/notification-preferences", headers=HEADERS, json={"user_id": str(uuid4())}
        ).status_code
        == 422
    )
    for operation in ["read", "dismiss"]:
        assert (
            client.patch(
                f"/api/v1/notifications/{row['id']}/{operation}", headers=HEADERS
            ).status_code
            == 200
        )
        repo.notification.assert_awaited_with(USER_ID, UUID(row["id"]), operation)
    assert client.post(
        "/api/v1/notifications/mark-all-read", headers=HEADERS, json={"household_id": str(HOME)}
    ).json() == {"updated": 2}
    assert (
        client.post(
            "/api/v1/devices/fcm-token",
            headers=HEADERS,
            json={
                "token": "valid-target-1234567890",
                "device_identifier": str(uuid4()),
                "platform": "android",
            },
        ).status_code
        == 200
    )
    assert (
        client.request(
            "DELETE",
            "/api/v1/devices/fcm-token",
            headers=HEADERS,
            json={"device_identifier": str(uuid4())},
        ).status_code
        == 200
    )
    assert client.get("/api/v1/notifications/" + row["id"], headers=HEADERS).json()[
        "recipient_user_id"
    ] == str(USER_ID)


def test_hub_api_does_not_accept_client_notification_generation(client):
    assert (
        client.post("/api/v1/notifications", headers=HEADERS, json=notification_data()).status_code
        == 405
    )


@pytest.mark.parametrize(
    "error,outcome,category",
    [
        (messaging.UnregisteredError("secret token"), "invalid_token", "unregistered"),
        (messaging.SenderIdMismatchError("secret token"), "permanent", "sender_mismatch"),
        (exceptions.UnavailableError("secret token"), "retry", "transient_fcm"),
        (messaging.QuotaExceededError("secret token"), "retry", "transient_fcm"),
        (exceptions.InvalidArgumentError("secret token"), "permanent", "invalid_argument"),
        (exceptions.PermissionDeniedError("secret token"), "permanent", "firebase_configuration"),
        (DefaultCredentialsError("private credential path"), "permanent", "firebase_configuration"),
        (RuntimeError("secret token"), "retry", "transport_or_unknown"),
    ],
)
async def test_fcm_error_classification_without_sensitive_logs(
    monkeypatch, capsys, error, outcome, category
):
    sender = FirebaseSender.__new__(FirebaseSender)
    sender.app = object()
    monkeypatch.setattr(messaging, "send", Mock(side_effect=error))
    result = await sender.send(
        {
            "token": "secret-target",
            "notification_id": str(uuid4()),
            "household_id": str(HOME),
            "event_type": "chat_message",
        }
    )
    assert result == (outcome, category)
    assert "secret" not in capsys.readouterr().out


async def test_fcm_payload_is_generic_minimal_and_os_deduplicated(monkeypatch):
    sender = FirebaseSender.__new__(FirebaseSender)
    sender.app = object()
    sent = Mock(return_value="message-id")
    monkeypatch.setattr(messaging, "send", sent)
    payload = {
        "token": "private-target",
        "notification_id": str(uuid4()),
        "household_id": str(HOME),
        "event_type": "chat_mention",
        "body": "private family message",
        "title": "Private repair",
    }
    assert await sender.send(payload) == ("sent", None)
    message = sent.call_args.args[0]
    assert message.fid == "private-target" and set(message.data) == {
        "notification_id",
        "household_id",
        "event_type",
    }
    assert message.notification.title == "HomeCircle" and "private" not in message.notification.body
    assert message.android.notification.tag == payload["notification_id"]


async def test_worker_reauthorizes_claims_and_does_not_send_suppressed_or_duplicate_jobs():
    first, second = uuid4(), uuid4()
    lease = uuid4()
    store = SimpleNamespace(
        claim=AsyncMock(
            side_effect=[
                [{"job_id": first, "lease": lease}, {"job_id": second, "lease": lease}],
                [],
            ]
        ),
        authorize=AsyncMock(side_effect=[None, {"token": "target"}]),
        finish=AsyncMock(return_value=True),
    )
    sender = SimpleNamespace(send=AsyncMock(return_value=("sent", None)))
    assert await process_batch(store, sender) == {"suppressed_or_stale": 1, "sent": 1}
    assert await process_batch(store, sender) == {}
    assert sender.send.await_count == 1
    store.finish.assert_awaited_once_with(second, lease, "sent", None)


async def test_worker_handles_stale_acknowledgement_without_claiming_success():
    identity, lease = uuid4(), uuid4()
    store = SimpleNamespace(
        claim=AsyncMock(return_value=[{"job_id": identity, "lease": lease}]),
        authorize=AsyncMock(return_value={"token": "target"}),
        finish=AsyncMock(return_value=False),
    )
    sender = SimpleNamespace(send=AsyncMock(return_value=("retry", "transient_fcm")))
    assert await process_batch(store, sender) == {"stale_acknowledgement": 1}
