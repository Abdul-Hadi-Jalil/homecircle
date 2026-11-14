from datetime import datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, Response

from app.api.v1.households import User
from app.repositories.hub import HubRepository
from app.schemas.hub import (
    ActivityPage,
    Category,
    Dashboard,
    DeviceRegistration,
    DeviceRemoval,
    HouseholdZone,
    Notification,
    NotificationPage,
    Preferences,
    PreferencesPatch,
    ReadAll,
)
from app.services.hub import HubService


def private_response(response: Response):
    response.headers["Cache-Control"] = "no-store"


router = APIRouter(tags=["household hub"], dependencies=[Depends(private_response)])


def get_hub(request: Request):
    return HubService(HubRepository(request.app.state.pool))


Service = Annotated[HubService, Depends(get_hub)]
Cursor = Annotated[str | None, Query(max_length=1000)]
Size = Annotated[int, Query(ge=1, le=100)]


@router.get("/households/{household_id}/dashboard", response_model=Dashboard)
async def dashboard(household_id: UUID, user: User, service: Service):
    return await service.dashboard(user.id, household_id)


@router.patch("/households/{household_id}/dashboard-settings")
async def zone(household_id: UUID, data: HouseholdZone, user: User, service: Service):
    return await service.zone(user.id, household_id, data.time_zone)


@router.get("/households/{household_id}/activity", response_model=ActivityPage)
async def activity(
    household_id: UUID,
    user: User,
    service: Service,
    category: Category | None = None,
    event_type: Annotated[str | None, Query(max_length=80)] = None,
    start: datetime | None = None,
    end: datetime | None = None,
    cursor: Cursor = None,
    page_size: Size = 30,
):
    return await service.activity(
        user.id, household_id, category, event_type, start, end, cursor, page_size
    )


@router.get("/notifications", response_model=NotificationPage)
async def notifications(
    user: User,
    service: Service,
    household_id: UUID | None = None,
    unread_only: bool = False,
    cursor: Cursor = None,
    page_size: Size = 30,
):
    return await service.notifications(user.id, household_id, unread_only, cursor, page_size)


@router.get("/notifications/unread-count")
async def unread(user: User, service: Service, household_id: UUID | None = None):
    return await service.unread(user.id, household_id)


@router.post("/notifications/mark-all-read")
async def read_all(data: ReadAll, user: User, service: Service):
    return await service.read_all(user.id, data.household_id)


@router.get("/notifications/{notification_id}", response_model=Notification)
async def notification(notification_id: UUID, user: User, service: Service):
    return await service.notification(user.id, notification_id)


@router.patch("/notifications/{notification_id}/read", response_model=Notification)
async def read(notification_id: UUID, user: User, service: Service):
    return await service.notification(user.id, notification_id, "read")


@router.patch("/notifications/{notification_id}/dismiss", response_model=Notification)
async def dismiss(notification_id: UUID, user: User, service: Service):
    return await service.notification(user.id, notification_id, "dismiss")


@router.post("/devices/fcm-token")
async def register(data: DeviceRegistration, user: User, service: Service):
    return await service.register(user.id, data)


@router.delete("/devices/fcm-token")
async def revoke(data: DeviceRemoval, user: User, service: Service):
    return await service.revoke(user.id, data.device_identifier)


@router.get("/households/{household_id}/notification-preferences", response_model=Preferences)
async def preferences(household_id: UUID, user: User, service: Service):
    return await service.preferences(user.id, household_id)


@router.patch("/households/{household_id}/notification-preferences", response_model=Preferences)
async def update_preferences(
    household_id: UUID, data: PreferencesPatch, user: User, service: Service
):
    return await service.preferences(user.id, household_id, data.model_dump(exclude_unset=True))
