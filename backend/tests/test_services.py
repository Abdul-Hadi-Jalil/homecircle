from unittest.mock import AsyncMock

import pytest

from app.core.exceptions import AppError
from app.models.auth import AuthenticatedUser
from app.schemas.household import HouseholdCreate
from app.services.households import HouseholdService
from tests.conftest import HOUSEHOLD_ID, OTHER_ID, USER_ID
from tests.test_api import household


async def test_service_checks_membership_for_verified_user():
    repository = AsyncMock()
    repository.get_for_user.return_value = None
    service = HouseholdService(repository)
    with pytest.raises(AppError) as error:
        await service.get_household(AuthenticatedUser(OTHER_ID), HOUSEHOLD_ID)
    assert error.value.status == 404
    repository.get_for_user.assert_awaited_once_with(OTHER_ID, HOUSEHOLD_ID)


async def test_creation_uses_verified_actor_and_atomic_repository_operation():
    repository = AsyncMock()
    repository.create.return_value = household().model_dump()
    service = HouseholdService(repository)
    result = await service.create_household(
        AuthenticatedUser(USER_ID), HouseholdCreate(name="Home")
    )
    assert result.role == "admin"
    repository.create.assert_awaited_once_with(USER_ID, "Home", None, None)


async def test_creation_passes_a_validated_avatar_key():
    repository = AsyncMock()
    repository.create.return_value = {**household().model_dump(), "avatar_key": "forest"}
    service = HouseholdService(repository)
    result = await service.create_household(
        AuthenticatedUser(USER_ID), HouseholdCreate(name="Home", avatar_key="forest")
    )
    assert result.avatar_key == "forest"
    repository.create.assert_awaited_once_with(USER_ID, "Home", None, "forest")


def test_unknown_avatar_keys_are_rejected():
    import pytest
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        HouseholdCreate(name="Home", avatar_key="../../etc/passwd")


def admin_repository(role="admin"):
    repository = AsyncMock()
    repository.get_for_user.return_value = {**household().model_dump(), "role": role}
    return repository


async def test_member_management_requires_admin_before_touching_memberships():
    repository = admin_repository(role="member")
    service = HouseholdService(repository)
    for call in (
        service.set_member_role(AuthenticatedUser(USER_ID), HOUSEHOLD_ID, OTHER_ID, "admin"),
        service.remove_member(AuthenticatedUser(USER_ID), HOUSEHOLD_ID, OTHER_ID),
        service.delete_household(AuthenticatedUser(USER_ID), HOUSEHOLD_ID),
    ):
        with pytest.raises(AppError) as error:
            await call
        assert error.value.status == 403
    repository.set_member_role.assert_not_awaited()
    repository.remove_member.assert_not_awaited()
    repository.delete_household.assert_not_awaited()


async def test_last_admin_violations_become_conflicts():
    from psycopg.errors import CheckViolation

    repository = admin_repository()
    repository.set_member_role.side_effect = CheckViolation()
    repository.remove_member.side_effect = CheckViolation()
    repository.leave.side_effect = CheckViolation()
    service = HouseholdService(repository)
    user = AuthenticatedUser(USER_ID)
    for call in (
        service.set_member_role(user, HOUSEHOLD_ID, OTHER_ID, "member"),
        service.remove_member(user, HOUSEHOLD_ID, OTHER_ID),
        service.leave(user, HOUSEHOLD_ID),
    ):
        with pytest.raises(AppError) as error:
            await call
        assert error.value.status == 409
        assert error.value.code == "last_admin"


async def test_any_member_can_leave_and_only_admins_delete():
    repository = admin_repository(role="member")
    service = HouseholdService(repository)
    await service.leave(AuthenticatedUser(USER_ID), HOUSEHOLD_ID)
    repository.leave.assert_awaited_once_with(USER_ID, HOUSEHOLD_ID)
    repository = admin_repository()
    repository.delete_household.return_value = True
    await HouseholdService(repository).delete_household(AuthenticatedUser(USER_ID), HOUSEHOLD_ID)
    repository.delete_household.assert_awaited_once_with(USER_ID, HOUSEHOLD_ID)
