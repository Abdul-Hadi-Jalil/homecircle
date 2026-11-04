from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class InvitationCode(BaseModel):
    model_config = ConfigDict(extra="forbid")
    code: str = Field(min_length=1, max_length=100)


class Invitation(BaseModel):
    id: UUID
    household_id: UUID
    created_by: UUID | None
    expires_at: datetime
    max_uses: int | None
    uses_count: int
    revoked_at: datetime | None
    created_at: datetime


class IssuedInvitation(BaseModel):
    invitation: Invitation
    code: str


class InvitationPreview(BaseModel):
    household_id: UUID
    name: str
    already_member: bool
