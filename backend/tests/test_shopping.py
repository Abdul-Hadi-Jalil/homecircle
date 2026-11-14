import asyncio
import copy
from contextlib import asynccontextmanager
from decimal import Decimal
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.api.v1.shopping import get_shopping, precise
from app.core.exceptions import AppError
from app.models.auth import AuthenticatedUser
from app.schemas.shopping import ApplyInventory, Purchase, ShoppingCreate, ShoppingUpdate
from app.schemas.task import Assignment, Revision, StatusUpdate
from app.services.shopping import PURCHASE_FIELDS, ShoppingService
from app.services.tasks import TaskService
from tests.test_tasks import ACTOR, HOME, SECOND, TASK, USER, FakeTasks, Result, task_row

ITEM = uuid4()


def shopping_row(**fields):
    return task_row(
        task_type="shopping",
        title="Cooking Oil",
        quantity=Decimal("5"),
        unit="L",
        **{k: None for k in PURCHASE_FIELDS},
        **fields,
    )


class FakeShopping(FakeTasks):
    def __init__(self):
        super().__init__(shopping_row())
        self.applications = {}
        self.stock = {
            "id": ITEM,
            "household_id": HOME,
            "quantity": Decimal(".5"),
            "unit": "L",
            "item_type": "consumable",
            "revision": 1,
        }

    @asynccontextmanager
    async def transaction(self, actor, household):
        async with self.lock:
            if household != HOME or actor not in (ACTOR, SECOND):
                raise AppError(404, "not_found", "Household not found")
            before = copy.deepcopy((self.row, self.events, self.applications, self.stock))
            try:
                yield self
            except Exception:
                self.row, self.events, self.applications, self.stock = before
                raise

    item = FakeTasks.task

    async def insert(self, c, table, fields):
        if table == "household_tasks":
            self.row = shopping_row()
            self.row.update(fields)
            return self.row.copy()
        if table == "shopping_item_details":
            self.row.update(fields)
            return fields
        self.applications[fields["purchase_id"]] = fields
        return fields

    async def write_details(self, c, household, task_id, fields):
        self.row.update(fields)

    async def execute(self, query, args=None):
        if "shopping_inventory_applications" in query:
            return Result(self.applications.get(args[-1]))
        return Result(None)


class FakeInventory:
    def __init__(self, repository):
        self.repository = repository

    async def item(self, c, household, item_id, **kwargs):
        if household != HOME or item_id != ITEM or self.repository.stock.get("deleted_at"):
            raise AppError(404, "not_found", "Inventory not found")
        return self.repository.stock.copy()

    async def write(self, c, actor, household, item_id, old, fields, action):
        self.repository.stock.update(fields)
        self.repository.stock["revision"] += 1
        return self.repository.stock.copy()


def service():
    repo = FakeShopping()
    instance = ShoppingService(repo)
    instance.inventory = FakeInventory(repo)
    return instance, repo


@pytest.mark.parametrize(
    "fields",
    [
        {"quantity": "0"},
        {"quantity": "-1"},
        {"quantity": "NaN"},
        {"quantity": "1.0001"},
        {"quantity": "1000000000000"},
        {"unit": "carton"},
        {"purchased_by": str(ACTOR)},
        {"purchase_price": "-1"},
        {"purchase_price": "1.001", "currency_code": "USD"},
    ],
)
def test_shopping_creation_rejects_invalid_or_forged_fields(fields):
    with pytest.raises(ValidationError):
        ShoppingCreate(title="Eggs", **fields)


@pytest.mark.parametrize(
    "fields",
    [
        {"purchase_price": "1"},
        {"currency_code": "USD"},
        {"purchase_price": "-1", "currency_code": "USD"},
        {"purchase_price": "1", "currency_code": "XXX"},
        {"purchased_by": str(SECOND)},
    ],
)
def test_purchase_money_and_actor_validation(fields):
    with pytest.raises(ValidationError):
        Purchase(expected_revision=1, **fields)


async def test_quick_add_creates_one_parent_and_details_atomically():
    shopping, repo = service()
    created = await shopping.create(USER, HOME, ShoppingCreate(title=" Eggs "))
    assert created["task_type"] == "shopping" and created["quantity"] is None
    assert created["title"] == "Eggs" and len(repo.events) == 1
    assert repo.events[0]["actor"] == ACTOR


async def test_linked_inventory_uses_exact_units_and_rejects_other_households():
    shopping, repo = service()
    created = await shopping.create(
        USER, HOME, ShoppingCreate(title="Oil", quantity="5", linked_inventory_item_id=ITEM)
    )
    assert created["unit"] == "L"
    with pytest.raises(AppError) as error:
        await shopping.update(USER, HOME, TASK, ShoppingUpdate(expected_revision=1, unit="mL"))
    assert error.value.code == "incompatible_unit"
    with pytest.raises(AppError):
        await shopping.create(
            USER, HOME, ShoppingCreate(title="Foreign", linked_inventory_item_id=uuid4())
        )
    assert repo.row["title"] == "Oil"


async def test_purchase_metadata_and_history_undo_without_stock_reversal():
    shopping, repo = service()
    repo.row["linked_inventory_item_id"] = ITEM
    purchased = await shopping.transition(
        USER,
        HOME,
        TASK,
        Purchase(expected_revision=1, purchase_price="1200.50", currency_code="PKR"),
        "completed",
    )
    assert purchased["purchased_by"] == ACTOR and purchased["status"] == "completed"
    assert repo.stock["quantity"] == Decimal(".5")
    application = ApplyInventory(expected_revision=2, purchase_id=purchased["purchase_id"])
    assert (await shopping.apply_inventory(USER, HOME, TASK, application))[
        "already_applied"
    ] is False
    assert (await shopping.apply_inventory(USER, HOME, TASK, application))[
        "already_applied"
    ] is True
    assert repo.stock["quantity"] == Decimal("5.5") and len(repo.applications) == 1
    reopened = await shopping.transition(USER, HOME, TASK, Revision(expected_revision=3), "open")
    assert all(reopened[k] is None for k in PURCHASE_FIELDS)
    assert repo.stock["quantity"] == Decimal("5.5")
    assert repo.events[0]["changes"]["purchase"]["purchase_price"] == "1200.50"
    assert repo.events[-1]["changes"]["inventory_requires_manual_correction"]
    repurchased = await shopping.transition(
        USER, HOME, TASK, Purchase(expected_revision=4), "completed"
    )
    assert repurchased["purchase_id"] != purchased["purchase_id"]
    with pytest.raises(AppError) as error:
        await shopping.apply_inventory(USER, HOME, TASK, application)
    assert error.value.code == "purchase_changed"


@pytest.mark.parametrize("operation", ["claim", "purchase", "apply"])
async def test_competing_writes_have_one_winner_or_one_idempotent_application(operation):
    shopping, repo = service()
    if operation == "apply":
        repo.row["linked_inventory_item_id"] = ITEM
        await shopping.transition(USER, HOME, TASK, Purchase(expected_revision=1), "completed")

    async def run(actor):
        user = AuthenticatedUser(actor, None)
        try:
            if operation == "claim":
                await shopping.assignment(
                    user, HOME, TASK, Assignment(operation="claim", expected_revision=1)
                )
            elif operation == "purchase":
                await shopping.transition(
                    user, HOME, TASK, Purchase(expected_revision=1), "completed"
                )
            else:
                await shopping.apply_inventory(
                    user,
                    HOME,
                    TASK,
                    ApplyInventory(expected_revision=2, purchase_id=repo.row["purchase_id"]),
                )
            return "ok"
        except AppError as error:
            return error.code

    results = sorted(await asyncio.gather(run(ACTOR), run(SECOND)))
    assert results == (["ok", "ok"] if operation == "apply" else ["ok", "revision_conflict"])
    if operation == "apply":
        assert repo.stock["quantity"] == Decimal("5.5") and len(repo.applications) == 1
    else:
        assert len(repo.events) == 1


async def test_inventory_failure_rolls_back_stock_and_ledger_but_keeps_purchase():
    shopping, repo = service()
    repo.row["linked_inventory_item_id"] = ITEM
    purchased = await shopping.transition(
        USER, HOME, TASK, Purchase(expected_revision=1), "completed"
    )
    repo.fail_event = True
    with pytest.raises(RuntimeError):
        await shopping.apply_inventory(
            USER,
            HOME,
            TASK,
            ApplyInventory(expected_revision=2, purchase_id=purchased["purchase_id"]),
        )
    assert repo.row["status"] == "completed" and repo.row["inventory_updated_at"] is None
    assert repo.stock["quantity"] == Decimal(".5") and not repo.applications


async def test_stale_undo_closed_edit_and_outsider_are_rejected():
    shopping, repo = service()
    await shopping.transition(USER, HOME, TASK, Purchase(expected_revision=1), "completed")
    with pytest.raises(AppError) as error:
        await shopping.transition(USER, HOME, TASK, Revision(expected_revision=1), "open")
    assert error.value.code == "revision_conflict"
    with pytest.raises(AppError):
        await shopping.update(
            USER, HOME, TASK, ShoppingUpdate(expected_revision=2, title="Rewrite receipt")
        )
    with pytest.raises(AppError):
        await shopping.detail(AuthenticatedUser(uuid4(), None), HOME, TASK)
    assert repo.row["status"] == "completed"


def test_http_contracts_validation_and_precise_decimal_encoding(client):
    mock = AsyncMock()
    row = precise(shopping_row())
    mock.create.return_value = row
    mock.detail.return_value = row
    mock.update.return_value = row
    mock.assignment.return_value = row
    mock.transition.return_value = row
    mock.apply_inventory.return_value = {"applied": True}
    mock.repository.listing.return_value = {"items": [row], "total": 1}
    mock.repository.summary.return_value = {"total": 1, "purchased": 0, "completion_percentage": 0}
    mock.repository.history.return_value = {"items": []}
    client.app.dependency_overrides[get_shopping] = lambda: mock
    root = f"/api/v1/households/{HOME}/shopping"
    headers = {"Authorization": "Bearer valid-token"}
    assert client.get(root).status_code == 401
    assert client.post(root, headers=headers, json={"title": "Oil"}).status_code == 201
    assert client.get(root, headers=headers).json()["items"][0]["quantity"] == "5"
    for suffix in ["/summary", "/history", f"/{TASK}"]:
        assert client.get(root + suffix, headers=headers).status_code == 200
    assert (
        client.patch(
            root + f"/{TASK}", headers=headers, json={"title": "Oil", "expected_revision": 1}
        ).status_code
        == 200
    )
    for action in ["claim", "purchase", "undo-purchase", "cancel"]:
        assert (
            client.post(
                root + f"/{TASK}/{action}", headers=headers, json={"expected_revision": 1}
            ).status_code
            == 200
        )
    assert (
        client.patch(
            root + f"/{TASK}/assignment",
            headers=headers,
            json={"expected_revision": 1, "operation": "unassign"},
        ).status_code
        == 200
    )
    assert (
        client.post(
            root + f"/{TASK}/apply-inventory",
            headers=headers,
            json={"expected_revision": 1, "purchase_id": str(uuid4())},
        ).status_code
        == 200
    )
    for query in ["priority=critical", "sort=sql", "page_size=500", "view=unknown"]:
        assert client.get(root + "?" + query, headers=headers).status_code == 422
    assert (
        client.post(
            root, headers=headers, json={"title": "Oil", "purchased_by": str(ACTOR)}
        ).status_code
        == 422
    )


async def test_generic_task_status_uses_shopping_metadata_and_explicit_reopen(monkeypatch):
    shopping, repo = service()
    repo.pool = None
    monkeypatch.setattr("app.services.shopping.shopping_service", lambda pool: shopping)
    tasks = TaskService(repo)
    completed = await tasks.status(
        USER, HOME, TASK, StatusUpdate(expected_revision=1, status="completed")
    )
    assert completed["purchased_by"] == ACTOR and completed["purchase_id"] is not None
    assert repo.stock["quantity"] == Decimal(".5")
    with pytest.raises(AppError) as error:
        await tasks.status(USER, HOME, TASK, StatusUpdate(expected_revision=2, status="open"))
    assert error.value.code == "explicit_reopen_required"
    reopened = await tasks.status(
        USER, HOME, TASK, StatusUpdate(expected_revision=2, status="open", reopen=True)
    )
    assert reopened["purchase_id"] is None and repo.events[-1]["action"] == "reopened"


@pytest.mark.parametrize("active,purchased,percentage", [(0, 0, 0), (3, 3, 50), (0, 4, 100)])
async def test_summary_denominator_excludes_cancelled_and_handles_empty(
    active, purchased, percentage
):
    from app.repositories.shopping import ShoppingRepository

    class SummaryRepository(ShoppingRepository):
        @asynccontextmanager
        async def transaction(self, actor, household):
            yield self

        async def execute(self, query, args):
            assert "status='completed'" in query and "private" not in query
            assert args[0] == ACTOR and HOME in args
            return Result(
                {"active": active, "purchased": purchased, "high_priority": 0, "assigned_to_me": 0}
            )

    result = await SummaryRepository(None).summary(ACTOR, HOME, {})
    assert result["total"] == active + purchased and result["completion_percentage"] == percentage
