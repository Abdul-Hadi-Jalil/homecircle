from datetime import date, datetime
from decimal import Decimal
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request

from app.api.v1.households import User
from app.schemas.shopping import ApplyInventory, Purchase, ShoppingCreate, ShoppingUpdate
from app.schemas.task import Assignment, Priority, Revision
from app.services.shopping import shopping_service

router = APIRouter(prefix="/households/{household_id}/shopping", tags=["shopping"])


def get_shopping(request: Request):
    return shopping_service(request.app.state.pool)


Service = Annotated[object, Depends(get_shopping)]


def filters(
    search: str = Query("", max_length=150),
    priority: Priority | None = None,
    assignment: Literal["all", "me", "unassigned"] = "all",
    assigned_to: UUID | None = None,
    linked_inventory_item_id: UUID | None = None,
    view: Literal["all", "active", "purchased", "cancelled"] = "all",
    archived: bool = False,
    sort: Literal["priority", "created", "updated", "due_date"] = "priority",
    page: int = Query(1, ge=1, le=100000),
    page_size: int = Query(20, ge=1, le=100),
):
    return dict(
        search=search,
        priority=priority,
        assignment=assignment,
        assigned_to=assigned_to,
        linked_inventory_item_id=linked_inventory_item_id,
        view=view,
        archived=archived,
        sort=sort,
        page=page,
        page_size=page_size,
    )


Filters = Annotated[dict, Depends(filters)]


def precise(value):
    if isinstance(value, dict):
        return {k: precise(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [precise(v) for v in value]
    if isinstance(value, (Decimal, UUID)):
        return str(value)
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return value


@router.get("")
async def listing(household_id: UUID, user: User, service: Service, query: Filters):
    return precise(await service.repository.listing(user.id, household_id, query))


@router.get("/summary")
async def summary(household_id: UUID, user: User, service: Service, query: Filters):
    return await service.repository.summary(user.id, household_id, query)


@router.get("/history")
async def history(household_id: UUID, user: User, service: Service, query: Filters):
    return precise(await service.repository.history(user.id, household_id, query))


@router.post("", status_code=201)
async def create(household_id: UUID, data: ShoppingCreate, user: User, service: Service):
    return precise(await service.create(user, household_id, data))


@router.get("/{task_id}")
async def detail(household_id: UUID, task_id: UUID, user: User, service: Service):
    return precise(await service.detail(user, household_id, task_id))


@router.patch("/{task_id}")
async def update(
    household_id: UUID, task_id: UUID, data: ShoppingUpdate, user: User, service: Service
):
    return precise(await service.update(user, household_id, task_id, data))


@router.post("/{task_id}/claim")
async def claim(household_id: UUID, task_id: UUID, data: Revision, user: User, service: Service):
    return precise(
        await service.assignment(
            user,
            household_id,
            task_id,
            Assignment(expected_revision=data.expected_revision, operation="claim"),
        )
    )


@router.patch("/{task_id}/assignment")
async def assignment(
    household_id: UUID, task_id: UUID, data: Assignment, user: User, service: Service
):
    return precise(await service.assignment(user, household_id, task_id, data))


@router.post("/{task_id}/purchase")
async def purchase(household_id: UUID, task_id: UUID, data: Purchase, user: User, service: Service):
    return precise(await service.transition(user, household_id, task_id, data, "completed"))


@router.post("/{task_id}/undo-purchase")
async def undo(household_id: UUID, task_id: UUID, data: Revision, user: User, service: Service):
    return precise(await service.transition(user, household_id, task_id, data, "open"))


@router.post("/{task_id}/cancel")
async def cancel(household_id: UUID, task_id: UUID, data: Revision, user: User, service: Service):
    return precise(await service.transition(user, household_id, task_id, data, "cancelled"))


@router.post("/{task_id}/apply-inventory")
async def apply(
    household_id: UUID, task_id: UUID, data: ApplyInventory, user: User, service: Service
):
    return precise(await service.apply_inventory(user, household_id, task_id, data))
