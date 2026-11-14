from datetime import UTC, datetime
from decimal import Decimal

from psycopg.errors import CheckViolation, ForeignKeyViolation, UniqueViolation
from pydantic import ValidationError

from app.core.exceptions import AppError
from app.schemas.inventory import InventoryFields

EDITABLE = set(InventoryFields.model_fields)


def stock_status(quantity, minimum=None):
    if quantity == Decimal(0):
        return "out_of_stock"
    return "low_stock" if minimum is not None and quantity <= minimum else "available"


def revision(old, expected):
    if old["revision"] != expected:
        raise AppError(
            409, "revision_conflict", "This item was updated. Refresh to review the latest changes."
        )


def adjusted_quantity(current, operation, amount):
    quantity = (
        amount if operation == "set" else current + (amount if operation == "increase" else -amount)
    )
    if quantity < 0 or quantity > Decimal("999999999999.999"):
        raise AppError(422, "invalid_quantity", "Final quantity is outside the allowed range.")
    return quantity


class InventoryService:
    def __init__(self, repository):
        self.repository = repository

    async def list(self, user, household, filters):
        return await self.repository.list(user.id, household, filters)

    async def detail(self, user, household, item_id):
        return await self.repository.detail(user.id, household, item_id)

    async def summary(self, user, household):
        return await self.repository.summary(user.id, household)

    async def activity(self, user, household, item_id, page, page_size):
        return await self.repository.activity(user.id, household, item_id, page, page_size)

    async def categories(self, user, household):
        return await self.repository.categories(user.id, household)

    async def create_category(self, user, household, data):
        try:
            return await self.repository.create_category(user.id, household, data.name)
        except UniqueViolation:
            raise AppError(409, "duplicate_category", "Category already exists.") from None

    async def create(self, user, household, data):
        try:
            return await self.repository.create(user.id, household, data.model_dump())
        except (CheckViolation, ForeignKeyViolation):
            raise AppError(
                422, "validation_error", "Item references or fields are invalid."
            ) from None

    async def update(self, user, household, item_id, data):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.item(c, household, item_id, lock=True)
            revision(old, data.expected_revision)
            fields = data.model_dump(exclude_unset=True, exclude={"expected_revision"})
            try:
                valid = InventoryFields.model_validate({**{k: old[k] for k in EDITABLE}, **fields})
            except ValidationError:
                raise AppError(
                    422, "validation_error", "Invalid item fields for this item type."
                ) from None
            fields = {k: valid.model_dump()[k] for k in fields}
            if not fields or all(old[k] == v for k, v in fields.items()):
                return old
            try:
                return await self.repository.write(
                    c, user.id, household, item_id, old, fields, "updated"
                )
            except (CheckViolation, ForeignKeyViolation):
                raise AppError(
                    422, "validation_error", "Invalid category or item fields."
                ) from None

    async def quantity(self, user, household, item_id, data):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.item(c, household, item_id, lock=True)
            if data.expected_revision is not None:
                revision(old, data.expected_revision)
            if old["item_type"] != "consumable":
                raise AppError(422, "wrong_item_type", "Quantity applies only to consumables.")
            quantity = adjusted_quantity(old["quantity"], data.operation, data.amount)
            if quantity == old["quantity"]:
                return old
            return await self.repository.write(
                c, user.id, household, item_id, old, {"quantity": quantity}, "quantity_changed"
            )

    async def condition(self, user, household, item_id, data):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.item(c, household, item_id, lock=True)
            revision(old, data.expected_revision)
            if old["item_type"] != "durable":
                raise AppError(422, "wrong_item_type", "Condition applies only to durable items.")
            if old["condition"] == data.condition:
                return old
            return await self.repository.write(
                c,
                user.id,
                household,
                item_id,
                old,
                {"condition": data.condition},
                "condition_changed",
            )

    async def archive(self, user, household, item_id, expected, restore=False):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.item(c, household, item_id, lock=True, archived=True)
            revision(old, expected)
            if (old["deleted_at"] is None) == (not restore):
                return await self.repository.write(
                    c,
                    user.id,
                    household,
                    item_id,
                    old,
                    {"deleted_at": None if restore else datetime.now(UTC)},
                    "restored" if restore else "archived",
                )
            return old
