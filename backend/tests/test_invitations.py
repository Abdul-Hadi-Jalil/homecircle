from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from pydantic import SecretStr

from app.core.exceptions import AppError
from app.models.auth import AuthenticatedUser
from app.services.invitations import InvitationService
from tests.conftest import HOUSEHOLD_ID, USER_ID


@pytest.fixture
def invitations(settings):
    settings.invitation_pepper = SecretStr("test-pepper-with-at-least-32-characters")
    repository, households = AsyncMock(), AsyncMock()
    repository.consume_attempt.return_value = True
    return InvitationService(repository, households, settings)


async def test_issuance_checks_admin_and_persists_only_hash(invitations):
    invitations.repository.issue.return_value = {
        "id": uuid4(),
        "household_id": HOUSEHOLD_ID,
        "created_by": USER_ID,
        "expires_at": datetime.now(UTC) + timedelta(days=7),
        "max_uses": 10,
        "uses_count": 0,
        "revoked_at": None,
        "created_at": datetime.now(UTC),
    }
    result = await invitations.issue(AuthenticatedUser(USER_ID), HOUSEHOLD_ID)
    invitations.households.require_admin.assert_awaited_once()
    args = invitations.repository.issue.call_args.args
    assert len(args[2]) == 64
    assert result.code not in str(args)
    assert "code_hash" not in result.invitation.model_dump()


@pytest.mark.parametrize("operation", ["issue", "list", "revoke"])
async def test_member_cannot_manage_invitations(invitations, operation):
    invitations.households.require_admin.side_effect = AppError(403, "forbidden", "Admin required")
    args = {"issue": (), "list": (50, 0), "revoke": (uuid4(),)}[operation]
    with pytest.raises(AppError) as error:
        await getattr(invitations, operation)(AuthenticatedUser(USER_ID), HOUSEHOLD_ID, *args)
    assert error.value.status == 403
    assert invitations.repository.mock_calls == []


@pytest.mark.parametrize(
    "status", ["invalid_invitation", "expired_invitation", "revoked_invitation", "invitation_limit"]
)
async def test_unavailable_invitation_is_safe_and_consumes_attempt(invitations, status):
    invitations.repository.resolve.return_value = {"status": status}
    with pytest.raises(AppError) as error:
        await invitations.resolve(AuthenticatedUser(USER_ID), "HC-AAAA-AAAA-AAAA-AAAA")
    assert error.value.status == 400
    assert error.value.code == status
    invitations.repository.consume_attempt.assert_awaited_once_with(USER_ID)


async def test_malformed_code_counts_attempt(invitations):
    with pytest.raises(AppError):
        await invitations.resolve(AuthenticatedUser(USER_ID), "bad")
    invitations.repository.consume_attempt.assert_awaited_once()
    invitations.repository.resolve.assert_not_called()


async def test_rate_limit_stops_lookup(invitations):
    invitations.repository.consume_attempt.return_value = False
    with pytest.raises(AppError) as error:
        await invitations.resolve(AuthenticatedUser(USER_ID), "HC-AAAA-AAAA-AAAA-AAAA")
    assert error.value.status == 429
    invitations.repository.resolve.assert_not_called()


async def test_preview_exposes_only_minimum_metadata(invitations):
    invitations.repository.resolve.return_value = {
        "status": "ok",
        "household_id": HOUSEHOLD_ID,
        "name": "Family",
        "already_member": False,
        "role": None,
    }
    result = await invitations.resolve(AuthenticatedUser(USER_ID), "HC-AAAA-AAAA-AAAA-AAAA")
    assert set(result.model_dump()) == {"household_id", "name", "already_member"}
    invitations.households.get_household.assert_not_called()


async def test_redeem_reloads_authorized_household(invitations):
    invitations.repository.resolve.return_value = {"status": "ok", "household_id": HOUSEHOLD_ID}
    actor = AuthenticatedUser(USER_ID)
    await invitations.resolve(actor, "HC-AAAA-AAAA-AAAA-AAAA", redeem=True)
    invitations.households.get_household.assert_awaited_once_with(actor, HOUSEHOLD_ID)
