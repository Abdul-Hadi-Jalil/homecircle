from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, Response

from app.api.v1.households import User
from app.core.config import get_settings
from app.repositories.inventory import InventoryRepository
from app.schemas.inventory import (
    InventoryActivityPage,
    InventoryCategoryCreate,
    InventoryCategoryResponse,
    InventoryConditionUpdate,
    InventoryItemCreate,
    InventoryItemResponse,
    InventoryItemUpdate,
    InventoryListResponse,
    InventoryPhotoUpload,
    InventoryQuantityUpdate,
    InventorySummaryResponse,
    Revision,
)
from app.services.inventory import InventoryService
from app.services.inventory_photos import InventoryPhotos

router = APIRouter(prefix="/households/{household_id}/inventory", tags=["inventory"])


def get_inventory_service(request: Request):
    return InventoryService(InventoryRepository(request.app.state.pool))


Service = Annotated[InventoryService, Depends(get_inventory_service)]


def get_photos(service: Service):
    return InventoryPhotos(service.repository, get_settings())


Photos = Annotated[InventoryPhotos, Depends(get_photos)]


@router.put("/{item_id}/photo", response_model=InventoryItemResponse)
async def upload_photo(
    household_id: UUID,
    item_id: UUID,
    data: InventoryPhotoUpload,
    user: User,
    photos: Photos,
    request: Request,
    response: Response,
):
    response.headers["Cache-Control"] = "no-store"
    return await photos.upload(user, household_id, item_id, data, request.headers["authorization"])


@router.get("/{item_id}/photo")
async def read_photo(
    household_id: UUID,
    item_id: UUID,
    user: User,
    photos: Photos,
    request: Request,
    response: Response,
):
    response.headers["Cache-Control"] = "no-store"
    return await photos.read(user, household_id, item_id, request.headers["authorization"])


@router.delete("/{item_id}/photo", response_model=InventoryItemResponse)
async def remove_photo(
    household_id: UUID,
    item_id: UUID,
    user: User,
    photos: Photos,
    request: Request,
    expected_revision: int = Query(ge=1),
):
    return await photos.remove(
        user, household_id, item_id, expected_revision, request.headers["authorization"]
    )


@router.get("/categories", response_model=list[InventoryCategoryResponse])
async def categories(household_id: UUID, user: User, service: Service):
    return await service.categories(user, household_id)


@router.post("/categories", response_model=InventoryCategoryResponse, status_code=201)
async def category(household_id: UUID, data: InventoryCategoryCreate, user: User, service: Service):
    return await service.create_category(user, household_id, data)


@router.get("/summary", response_model=InventorySummaryResponse)
async def summary(household_id: UUID, user: User, service: Service):
    return await service.summary(user, household_id)


@router.get("", response_model=InventoryListResponse)
async def items(
    household_id: UUID,
    user: User,
    service: Service,
    search: str = Query("", max_length=150),
    category: UUID | None = None,
    type: Literal["consumable", "durable"] | None = None,
    stock_status: Literal["available", "low_stock", "out_of_stock"] | None = None,
    condition: Literal["working", "needs_repair", "broken"] | None = None,
    sort: Literal["updated", "name", "oldest"] = "updated",
    page: int = Query(1, ge=1, le=100000),
    page_size: int = Query(20, ge=1, le=100),
    archived: bool = False,
    location: str | None = Query(None, max_length=150),
):
    return await service.list(
        user,
        household_id,
        {
            "search": search,
            "category": category,
            "type": type,
            "stock_status": stock_status,
            "condition": condition,
            "sort": sort,
            "page": page,
            "page_size": page_size,
            "archived": archived,
            "location": location,
        },
    )


@router.post("", response_model=InventoryItemResponse, status_code=201)
async def create(household_id: UUID, data: InventoryItemCreate, user: User, service: Service):
    return await service.create(user, household_id, data)


@router.get("/{item_id}", response_model=InventoryItemResponse)
async def detail(household_id: UUID, item_id: UUID, user: User, service: Service):
    return await service.detail(user, household_id, item_id)


@router.patch("/{item_id}", response_model=InventoryItemResponse)
async def update(
    household_id: UUID, item_id: UUID, data: InventoryItemUpdate, user: User, service: Service
):
    return await service.update(user, household_id, item_id, data)


@router.patch("/{item_id}/quantity", response_model=InventoryItemResponse)
async def quantity(
    household_id: UUID, item_id: UUID, data: InventoryQuantityUpdate, user: User, service: Service
):
    return await service.quantity(user, household_id, item_id, data)


@router.patch("/{item_id}/condition", response_model=InventoryItemResponse)
async def condition(
    household_id: UUID, item_id: UUID, data: InventoryConditionUpdate, user: User, service: Service
):
    return await service.condition(user, household_id, item_id, data)


@router.delete("/{item_id}", response_model=InventoryItemResponse)
async def archive(
    household_id: UUID,
    item_id: UUID,
    user: User,
    service: Service,
    expected_revision: int = Query(ge=1),
):
    return await service.archive(user, household_id, item_id, expected_revision)


@router.post("/{item_id}/restore", response_model=InventoryItemResponse)
async def restore(household_id: UUID, item_id: UUID, data: Revision, user: User, service: Service):
    return await service.archive(user, household_id, item_id, data.expected_revision, restore=True)


@router.get("/{item_id}/activity", response_model=InventoryActivityPage)
async def activity(
    household_id: UUID,
    item_id: UUID,
    user: User,
    service: Service,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    return await service.activity(user, household_id, item_id, page, page_size)
