from decimal import Decimal
from typing import Annotated, Literal
from uuid import UUID

from pydantic import Field, model_validator

from app.schemas.inventory import Unit
from app.schemas.task import Input, Priority, Revision

PositiveQuantity = Annotated[
    Decimal, Field(gt=0, max_digits=15, decimal_places=3, allow_inf_nan=False)
]
Price = Annotated[Decimal, Field(ge=0, max_digits=15, decimal_places=2, allow_inf_nan=False)]
Currency = Literal["PKR", "USD", "EUR", "GBP", "AED", "SAR", "INR", "CAD", "AUD", "JPY", "CNY"]


class ShoppingFields(Input):
    title: str = Field(min_length=1, max_length=150)
    quantity: PositiveQuantity | None = None
    unit: Unit | None = None
    priority: Priority = "normal"
    description: str | None = Field(default=None, max_length=4000)
    assigned_to: UUID | None = None
    linked_inventory_item_id: UUID | None = None


class ShoppingCreate(ShoppingFields):
    pass


class ShoppingUpdate(Revision):
    title: str | None = Field(default=None, min_length=1, max_length=150)
    quantity: PositiveQuantity | None = None
    unit: Unit | None = None
    priority: Priority | None = None
    description: str | None = Field(default=None, max_length=4000)
    assigned_to: UUID | None = None
    linked_inventory_item_id: UUID | None = None


class Purchase(Revision):
    actual_quantity: PositiveQuantity | None = None
    purchase_price: Price | None = None
    currency_code: Currency | None = None
    completion_note: str | None = Field(default=None, max_length=4000)

    @model_validator(mode="after")
    def money(self):
        if (self.purchase_price is None) != (self.currency_code is None):
            raise ValueError("Price and supported currency must be supplied together")
        return self


class ApplyInventory(Revision):
    purchase_id: UUID
