from datetime import date, datetime
from decimal import Decimal
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

Quantity = Annotated[Decimal, Field(ge=0, max_digits=15, decimal_places=3, allow_inf_nan=False)]
ItemType = Literal["consumable", "durable"]
Condition = Literal["working", "needs_repair", "broken"]
Unit = Literal["piece", "pack", "kg", "g", "L", "mL", "bottle", "box", "roll"]


class Input(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class InventoryCategoryCreate(Input):
    name: str = Field(min_length=1, max_length=80)


class InventoryCategoryResponse(InventoryCategoryCreate):
    id: UUID
    household_id: UUID | None


class InventoryFields(Input):
    name: str = Field(min_length=1, max_length=150)
    item_type: ItemType
    category_id: UUID | None = None
    quantity: Quantity | None = None
    unit: Unit | None = None
    minimum_quantity: Quantity | None = None
    condition: Condition | None = None
    location: str | None = Field(default=None, max_length=150)
    notes: str | None = Field(default=None, max_length=4000)
    purchase_date: date | None = None
    last_service_date: date | None = None

    @model_validator(mode="after")
    def valid_type(self):
        if self.item_type == "consumable":
            if (
                self.quantity is None
                or self.unit is None
                or self.condition is not None
                or self.purchase_date is not None
                or self.last_service_date is not None
            ):
                raise ValueError("Invalid consumable fields")
        elif self.condition is None or any(
            value is not None for value in (self.quantity, self.unit, self.minimum_quantity)
        ):
            raise ValueError("Invalid durable fields")
        return self


class InventoryItemCreate(InventoryFields):
    pass


class InventoryItemUpdate(Input):
    expected_revision: int = Field(ge=1)
    name: str | None = Field(default=None, min_length=1, max_length=150)
    item_type: ItemType | None = None
    category_id: UUID | None = None
    quantity: Quantity | None = None
    unit: Unit | None = None
    minimum_quantity: Quantity | None = None
    condition: Condition | None = None
    location: str | None = Field(default=None, max_length=150)
    notes: str | None = Field(default=None, max_length=4000)
    purchase_date: date | None = None
    last_service_date: date | None = None


class InventoryItemResponse(InventoryFields):
    id: UUID
    household_id: UUID
    category_name: str | None = None
    photo_path: str | None = None
    stock_status: Literal["available", "low_stock", "out_of_stock"] | None
    created_by: UUID
    updated_by: UUID
    updated_by_name: str | None = None
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    revision: int


class InventoryListResponse(BaseModel):
    items: list[InventoryItemResponse]
    total: int
    page: int
    page_size: int


class InventorySummaryResponse(BaseModel):
    total: int
    available: int
    low_stock: int
    out_of_stock: int
    working: int
    needs_repair: int
    broken: int


class InventoryQuantityUpdate(Input):
    operation: Literal["set", "increase", "decrease"]
    amount: Quantity
    expected_revision: int | None = Field(default=None, ge=1)

    @model_validator(mode="after")
    def require_set_revision(self):
        if self.operation == "set" and self.expected_revision is None:
            raise ValueError("Absolute quantity requires expected_revision")
        return self


class InventoryConditionUpdate(Input):
    condition: Condition
    expected_revision: int = Field(ge=1)


class Revision(Input):
    expected_revision: int = Field(ge=1)


class InventoryPhotoUpload(Revision):
    data_base64: str = Field(min_length=1, max_length=7_000_000)


class InventoryActivityResponse(BaseModel):
    id: UUID
    actor_user_id: UUID
    actor_name: str | None = None
    action: str
    changes: dict | None
    created_at: datetime


class InventoryActivityPage(BaseModel):
    items: list[InventoryActivityResponse]
    page: int
    page_size: int
