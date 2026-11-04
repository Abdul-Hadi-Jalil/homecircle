from datetime import UTC, datetime, timedelta

from psycopg.errors import InsufficientPrivilege

from app.core.exceptions import AppError
from app.schemas.invitation import Invitation, InvitationPreview, IssuedInvitation
from app.services.invitation_codes import generate_code, hash_code


class InvitationService:
    def __init__(self, repository, households, settings):
        self.repository = repository
        self.households = households
        self.settings = settings

    def pepper(self):
        if not self.settings.invitation_pepper:
            raise AppError(
                503, "invitation_unavailable", "Invitations are temporarily unavailable."
            )
        return self.settings.invitation_pepper.get_secret_value()

    async def issue(self, user, household_id):
        await self.households.require_admin(user, household_id)
        code = generate_code()
        digest = hash_code(code, self.pepper())
        try:
            row = await self.repository.issue(
                user.id,
                household_id,
                digest,
                datetime.now(UTC) + timedelta(days=self.settings.invitation_expiry_days),
                self.settings.invitation_max_uses,
            )
        except InsufficientPrivilege:
            raise AppError(
                403, "forbidden", "Household administrator access is required."
            ) from None
        return IssuedInvitation(invitation=Invitation.model_validate(row), code=code)

    async def list(self, user, household_id, limit, offset):
        await self.households.require_admin(user, household_id)
        return await self.repository.list(user.id, household_id, limit, offset)

    async def revoke(self, user, household_id, invitation_id):
        await self.households.require_admin(user, household_id)
        try:
            revoked = await self.repository.revoke(user.id, household_id, invitation_id)
        except InsufficientPrivilege:
            raise AppError(
                403, "forbidden", "Household administrator access is required."
            ) from None
        if not revoked:
            raise AppError(404, "not_found", "Invitation not found.")

    async def resolve(self, user, code, redeem=False):
        if not await self.repository.consume_attempt(user.id):
            raise AppError(
                429, "rate_limit", "Too many attempts. Please try again in five minutes."
            )
        result = await self.repository.resolve(user.id, hash_code(code, self.pepper()), redeem)
        status = result["status"]
        if status != "ok":
            messages = {
                "expired_invitation": "This invitation has expired.",
                "revoked_invitation": "This invitation was revoked.",
                "invitation_limit": "This invitation has reached its usage limit.",
            }
            raise AppError(400, status, messages.get(status, "This invitation is not available."))
        if redeem:
            return await self.households.get_household(user, result["household_id"])
        return InvitationPreview.model_validate(result)
