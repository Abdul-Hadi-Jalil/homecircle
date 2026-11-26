from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query

from app.dependencies.auth import get_current_user
from app.dependencies.services import get_household_service
from app.models.auth import AuthenticatedUser
from app.schemas.household import (
    Household,
    HouseholdCreate,
    HouseholdUpdate,
    Me,
    Member,
    MemberRoleUpdate,
    ProfileUpdate,
)
from app.services.households import HouseholdService

router = APIRouter()
User = Annotated[AuthenticatedUser, Depends(get_current_user)]
Service = Annotated[HouseholdService, Depends(get_household_service)]


@router.get("/me", response_model=Me)
async def me(user: User, service: Service):
    return await service.me(user)


@router.get("/households", response_model=list[Household])
async def list_households(user: User, service: Service):
    return await service.list_households(user)


@router.post("/households", response_model=Household, status_code=201)
async def create_household(data: HouseholdCreate, user: User, service: Service):
    return await service.create_household(user, data)


@router.get("/households/{household_id}", response_model=Household)
async def get_household(household_id: UUID, user: User, service: Service):
    return await service.get_household(user, household_id)


@router.patch("/me", response_model=Me)
async def update_me(data: ProfileUpdate, user: User, service: Service):
    return await service.update_profile(user, data)


@router.patch("/households/{household_id}", response_model=Household)
async def update_household(household_id: UUID, data: HouseholdUpdate, user: User, service: Service):
    return await service.update_household(user, household_id, data)


@router.patch("/households/{household_id}/members/{member_id}", status_code=204)
async def set_member_role(
    household_id: UUID, member_id: UUID, data: MemberRoleUpdate, user: User, service: Service
):
    await service.set_member_role(user, household_id, member_id, data.role)


@router.delete("/households/{household_id}/members/{member_id}", status_code=204)
async def remove_member(household_id: UUID, member_id: UUID, user: User, service: Service):
    await service.remove_member(user, household_id, member_id)


@router.post("/households/{household_id}/leave", status_code=204)
async def leave_household(household_id: UUID, user: User, service: Service):
    await service.leave(user, household_id)


@router.delete("/households/{household_id}", status_code=204)
async def delete_household(household_id: UUID, user: User, service: Service):
    await service.delete_household(user, household_id)


@router.get("/households/{household_id}/members", response_model=list[Member])
async def members(
    household_id: UUID,
    user: User,
    service: Service,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
):
    return await service.members(user, household_id, limit, offset)
