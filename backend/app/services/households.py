from uuid import UUID

from psycopg.errors import InsufficientPrivilege

from app.core.exceptions import AppError
from app.models.auth import AuthenticatedUser
from app.schemas.household import Household, HouseholdCreate, Me


class HouseholdService:
    def __init__(self, repository):
        self.repository = repository

    async def list_households(self, user: AuthenticatedUser) -> list[Household]:
        return [
            Household.model_validate(row) for row in await self.repository.list_for_user(user.id)
        ]

    async def get_household(self, user: AuthenticatedUser, household_id: UUID) -> Household:
        row = await self.repository.get_for_user(user.id, household_id)
        if row is None:
            # The same response for absent and unauthorized IDs prevents enumeration.
            raise AppError(404, "not_found", "Household not found.")
        return Household.model_validate(row)

    async def create_household(self, user: AuthenticatedUser, data: HouseholdCreate) -> Household:
        return Household.model_validate(
            await self.repository.create(user.id, data.name, data.description)
        )

    async def me(self, user: AuthenticatedUser) -> Me:
        profile = await self.repository.profile(user.id)
        return Me(
            id=user.id,
            email=user.email,
            display_name=profile["display_name"] if profile else "",
            avatar_path=profile.get("avatar_path") if profile else None,
            households=await self.list_households(user),
        )

    async def update_profile(self, user, data):
        await self.repository.update_profile(user.id, data.display_name)
        return await self.me(user)

    async def require_admin(self, user, household_id):
        home = await self.get_household(user, household_id)
        if home.role != "admin":
            raise AppError(403, "forbidden", "Household administrator access is required.")
        return home

    async def update_household(self, user, household_id, data):
        await self.require_admin(user, household_id)
        if not await self.repository.update_household(
            user.id, household_id, data.name, data.description
        ):
            raise AppError(403, "forbidden", "Household administrator access is required.")
        return await self.get_household(user, household_id)

    async def members(self, user, household_id, limit, offset):
        await self.get_household(user, household_id)
        try:
            return await self.repository.members(user.id, household_id, limit, offset)
        except InsufficientPrivilege:
            raise AppError(404, "not_found", "Household not found.") from None
