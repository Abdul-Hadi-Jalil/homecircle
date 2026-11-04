from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, Response

from app.api.v1.households import User
from app.core.config import get_settings
from app.dependencies.services import get_household_service
from app.repositories.invitations import InvitationRepository
from app.schemas.household import Household
from app.schemas.invitation import Invitation, InvitationCode, InvitationPreview, IssuedInvitation
from app.services.invitations import InvitationService

router = APIRouter()


def get_invitation_service(request: Request) -> InvitationService:
    return InvitationService(
        InvitationRepository(request.app.state.pool), get_household_service(request), get_settings()
    )


Service = Annotated[InvitationService, Depends(get_invitation_service)]


@router.post("/households/{household_id}/invites", response_model=IssuedInvitation, status_code=201)
async def issue(household_id: UUID, user: User, service: Service, response: Response):
    response.headers["Cache-Control"] = "no-store"
    return await service.issue(user, household_id)


@router.get("/households/{household_id}/invites", response_model=list[Invitation])
async def invitations(
    household_id: UUID,
    user: User,
    service: Service,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    return await service.list(user, household_id, limit, offset)


@router.delete("/households/{household_id}/invites/{invitation_id}", status_code=204)
async def revoke(household_id: UUID, invitation_id: UUID, user: User, service: Service):
    await service.revoke(user, household_id, invitation_id)


@router.post("/invites/preview", response_model=InvitationPreview)
async def preview(data: InvitationCode, user: User, service: Service):
    return await service.resolve(user, data.code)


@router.post("/invites/redeem", response_model=Household)
async def redeem(data: InvitationCode, user: User, service: Service):
    return await service.resolve(user, data.code, redeem=True)
