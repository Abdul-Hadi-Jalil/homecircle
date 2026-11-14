from datetime import UTC, datetime
from uuid import uuid4

from psycopg.errors import CheckViolation, ForeignKeyViolation
from pydantic import ValidationError

from app.core.exceptions import AppError
from app.repositories.inventory import InventoryRepository, snapshot
from app.repositories.shopping import ShoppingRepository
from app.schemas.shopping import Purchase, ShoppingFields
from app.services.inventory import adjusted_quantity
from app.services.tasks import check_revision

DETAIL_FIELDS = {"quantity", "unit", "linked_inventory_item_id"}
PURCHASE_FIELDS = (
    "purchase_id",
    "actual_quantity",
    "purchased_by",
    "purchased_at",
    "purchase_price",
    "currency_code",
    "inventory_updated_at",
)


class ShoppingService:
    def __init__(self, repository):
        self.repository = repository
        self.inventory = InventoryRepository(getattr(repository, "pool", None))

    async def detail(self, user, household, task_id):
        async with self.repository.transaction(user.id, household) as c:
            return await self.repository.item(c, household, task_id, archived=True)

    async def validate_link(self, c, household, fields):
        if fields.get("linked_inventory_item_id"):
            item = await self.inventory.item(c, household, fields["linked_inventory_item_id"])
            if item["item_type"] == "consumable":
                if fields.get("unit") is None:
                    fields["unit"] = item["unit"]
                if fields["unit"] != item["unit"]:
                    raise AppError(
                        422,
                        "incompatible_unit",
                        "Use the linked inventory unit; conversion is not supported.",
                    )

    async def create(self, user, household, data):
        fields = data.model_dump()
        try:
            async with self.repository.transaction(user.id, household) as c:
                await self.validate_link(c, household, fields)
                task = await self.repository.insert(
                    c,
                    "household_tasks",
                    {k: v for k, v in fields.items() if k not in DETAIL_FIELDS}
                    | {
                        "task_type": "shopping",
                        "household_id": household,
                        "created_by": user.id,
                        "updated_by": user.id,
                    },
                )
                await self.repository.insert(
                    c,
                    "shopping_item_details",
                    {
                        "task_id": task["id"],
                        "household_id": household,
                        **{k: fields[k] for k in DETAIL_FIELDS},
                    },
                )
                await self.repository.event(
                    c, user.id, household, task["id"], "created", snapshot(fields)
                )
                return await self.repository.item(c, household, task["id"])
        except (CheckViolation, ForeignKeyViolation):
            raise AppError(
                422, "invalid_reference", "Assignee or inventory is unavailable in this household."
            ) from None

    async def update(self, user, household, task_id, data):
        try:
            async with self.repository.transaction(user.id, household) as c:
                old = await self.repository.item(c, household, task_id, lock=True)
                check_revision(old, data.expected_revision)
                if old["status"] in ("completed", "cancelled"):
                    raise AppError(
                        409, "reopen_required", "Reopen before editing a closed shopping request."
                    )
                fields = data.model_dump(exclude_unset=True, exclude={"expected_revision"})
                try:
                    valid = ShoppingFields.model_validate(
                        {k: fields.get(k, old[k]) for k in ShoppingFields.model_fields}
                    ).model_dump()
                except ValidationError:
                    raise AppError(422, "validation_error", "Invalid shopping fields.") from None
                await self.validate_link(c, household, valid)
                await self.repository.write_details(
                    c, household, task_id, {k: valid[k] for k in DETAIL_FIELDS}
                )
                await self.repository.write(
                    c,
                    user.id,
                    household,
                    task_id,
                    {k: v for k, v in valid.items() if k not in DETAIL_FIELDS},
                )
                await self.repository.event(
                    c,
                    user.id,
                    household,
                    task_id,
                    "updated",
                    {"before": snapshot(old), "after": snapshot(valid)},
                )
                return await self.repository.item(c, household, task_id)
        except (CheckViolation, ForeignKeyViolation):
            raise AppError(
                422, "invalid_reference", "Assignee or linked inventory is unavailable."
            ) from None

    async def transition_locked(self, c, user, household, task_id, old, status, *, purchase=None):
        if status == "completed":
            if old["status"] not in ("open", "in_progress", "blocked"):
                raise AppError(
                    409, "already_purchased", "Only an outstanding request can be purchased."
                )
            purchase = purchase or Purchase(expected_revision=old["revision"])
            now = datetime.now(UTC)
            details = {
                "purchase_id": uuid4(),
                "actual_quantity": purchase.actual_quantity or old["quantity"],
                "purchased_by": user.id,
                "purchased_at": now,
                "purchase_price": purchase.purchase_price,
                "currency_code": purchase.currency_code,
                "inventory_updated_at": None,
            }
            await self.repository.write_details(c, household, task_id, details)
            await self.repository.write(
                c,
                user.id,
                household,
                task_id,
                {
                    "status": "completed",
                    "completed_at": now,
                    "cancelled_at": None,
                    "completion_note": purchase.completion_note,
                },
            )
            await self.repository.event(
                c,
                user.id,
                household,
                task_id,
                "completed",
                {
                    "purchase": snapshot(
                        {
                            **details,
                            "quantity": details["actual_quantity"],
                            "unit": old["unit"],
                            "linked_inventory_item_id": old["linked_inventory_item_id"],
                            "title": old["title"],
                            "completion_note": purchase.completion_note,
                        }
                    )
                },
            )
        elif status == "open":
            if old["status"] not in ("completed", "cancelled"):
                raise AppError(409, "invalid_transition", "Only a closed request can be reopened.")
            await self.repository.write_details(
                c, household, task_id, {k: None for k in PURCHASE_FIELDS}
            )
            await self.repository.write(
                c,
                user.id,
                household,
                task_id,
                {
                    "status": "open",
                    "completed_at": None,
                    "cancelled_at": None,
                    "completion_note": None,
                },
            )
            await self.repository.event(
                c,
                user.id,
                household,
                task_id,
                "reopened",
                {
                    "previous_purchase": snapshot({k: old[k] for k in PURCHASE_FIELDS}),
                    "inventory_requires_manual_correction": old["inventory_updated_at"] is not None,
                },
            )
        elif status in ("cancelled", "in_progress", "blocked"):
            if old["status"] in ("completed", "cancelled"):
                raise AppError(409, "reopen_required", "Reopen before changing a closed request.")
            await self.repository.write(
                c,
                user.id,
                household,
                task_id,
                {
                    "status": status,
                    "cancelled_at": datetime.now(UTC) if status == "cancelled" else None,
                },
            )
            await self.repository.event(
                c,
                user.id,
                household,
                task_id,
                "cancelled" if status == "cancelled" else "status_changed",
                {"status": {"before": old["status"], "after": status}},
            )
        else:
            raise AppError(422, "invalid_transition", "Unsupported shopping transition.")
        return await self.repository.item(c, household, task_id)

    async def transition(self, user, household, task_id, data, status):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.item(c, household, task_id, lock=True)
            check_revision(old, data.expected_revision)
            return await self.transition_locked(
                c,
                user,
                household,
                task_id,
                old,
                status,
                purchase=data if isinstance(data, Purchase) else None,
            )

    async def assignment(self, user, household, task_id, data):
        try:
            async with self.repository.transaction(user.id, household) as c:
                old = await self.repository.item(c, household, task_id, lock=True)
                check_revision(old, data.expected_revision)
                if old["status"] in ("completed", "cancelled"):
                    raise AppError(409, "reopen_required", "Reopen before changing responsibility.")
                if data.operation == "claim" and old["assigned_to"] is not None:
                    raise AppError(
                        409, "already_claimed", "Someone has already claimed this request."
                    )
                target = user.id if data.operation == "claim" else data.assigned_to
                await self.repository.write(c, user.id, household, task_id, {"assigned_to": target})
                await self.repository.event(
                    c,
                    user.id,
                    household,
                    task_id,
                    "claimed"
                    if data.operation == "claim"
                    else "assigned"
                    if target
                    else "unassigned",
                    {
                        "assigned_to": {
                            "before": str(old["assigned_to"]) if old["assigned_to"] else None,
                            "after": str(target) if target else None,
                        }
                    },
                )
                return await self.repository.item(c, household, task_id)
        except (CheckViolation, ForeignKeyViolation):
            raise AppError(
                422, "invalid_reference", "Assignee is not a household member."
            ) from None

    async def apply_inventory(self, user, household, task_id, data):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.item(c, household, task_id, lock=True)
            # Check the purchase UUID before revisions: a retry of the same committed
            # operation returns success, but an old purchase cannot affect a new cycle.
            if old["status"] != "completed" or old["purchase_id"] != data.purchase_id:
                raise AppError(409, "purchase_changed", "The current purchase has changed.")
            prior = await (
                await c.execute(
                    "SELECT * FROM public.shopping_inventory_applications "
                    "WHERE household_id=%s AND task_id=%s AND purchase_id=%s",
                    (household, task_id, data.purchase_id),
                )
            ).fetchone()
            if prior:
                return {"applied": True, "already_applied": True, "purchase_id": data.purchase_id}
            check_revision(old, data.expected_revision)
            if old["linked_inventory_item_id"] is None or old["actual_quantity"] is None:
                raise AppError(
                    422,
                    "inventory_not_ready",
                    "Link inventory and specify quantity before purchasing.",
                )
            item = await self.inventory.item(
                c, household, old["linked_inventory_item_id"], lock=True
            )
            if item["item_type"] != "consumable" or item["unit"] != old["unit"]:
                raise AppError(
                    422,
                    "incompatible_unit",
                    "Only matching consumable units can be added to stock.",
                )
            quantity = adjusted_quantity(item["quantity"], "increase", old["actual_quantity"])
            await self.inventory.write(
                c, user.id, household, item["id"], item, {"quantity": quantity}, "quantity_changed"
            )
            await self.repository.insert(
                c,
                "shopping_inventory_applications",
                {
                    "purchase_id": data.purchase_id,
                    "household_id": household,
                    "task_id": task_id,
                    "inventory_item_id": item["id"],
                    "quantity": old["actual_quantity"],
                    "applied_by": user.id,
                },
            )
            await self.repository.write_details(
                c, household, task_id, {"inventory_updated_at": datetime.now(UTC)}
            )
            await self.repository.write(c, user.id, household, task_id, {})
            await self.repository.event(
                c,
                user.id,
                household,
                task_id,
                "updated",
                {
                    "inventory_application": snapshot(
                        {
                            "purchase_id": data.purchase_id,
                            "inventory_item_id": item["id"],
                            "quantity": old["actual_quantity"],
                            "unit": old["unit"],
                        }
                    )
                },
            )
            return {
                "applied": True,
                "already_applied": False,
                "purchase_id": data.purchase_id,
                "inventory_quantity": str(quantity),
            }


def shopping_service(pool):
    return ShoppingService(ShoppingRepository(pool))
