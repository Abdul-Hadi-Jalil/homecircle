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
    repository.create.assert_awaited_once_with(USER_ID, "Home", None)
