import base64
import io
from contextlib import asynccontextmanager
from datetime import UTC, datetime
from decimal import Decimal
from unittest.mock import AsyncMock
from uuid import uuid4

import httpx
import pytest
from PIL import Image
from pydantic import ValidationError

from app.api.v1.inventory import get_inventory_service, get_photos
from app.core.exceptions import AppError
from app.models.auth import AuthenticatedUser
from app.schemas.inventory import (
    InventoryConditionUpdate,
    InventoryFields,
    InventoryItemUpdate,
    InventoryPhotoUpload,
    InventoryQuantityUpdate,
)
from app.services.inventory import InventoryService, stock_status
from app.services.inventory_photos import InventoryPhotos, normalize_photo

ACTOR, HOME, ITEM = uuid4(), uuid4(), uuid4()
USER = AuthenticatedUser(ACTOR, "inventory@example.test")


def item(**overrides):
    return {
        "id": ITEM,
        "household_id": HOME,
        "name": "Rice",
        "item_type": "consumable",
        "category_id": None,
        "quantity": Decimal("3"),
        "unit": "kg",
        "minimum_quantity": Decimal("1"),
        "condition": None,
        "location": "Pantry",
        "notes": None,
        "purchase_date": None,
        "last_service_date": None,
        "photo_path": None,
        "created_by": ACTOR,
        "updated_by": ACTOR,
        "created_at": datetime.now(UTC),
        "updated_at": datetime.now(UTC),
        "revision": 2,
        "deleted_at": None,
        **overrides,
    }


class Repository:
    def __init__(self, row=None):
        self.row = row or item()
        self.connection = AsyncMock()
        self.writes = []
        self.fail = False

    @asynccontextmanager
    async def transaction(self, actor, household):
        before = self.row.copy()
        try:
            yield self.connection
        except Exception:
            self.row = before
            raise

    async def item(self, connection, household, item_id, **kwargs):
        if household != self.row["household_id"] or item_id != self.row["id"]:
            raise AppError(404, "not_found", "Item not found")
        if self.row["deleted_at"] and not kwargs.get("archived"):
            raise AppError(404, "not_found", "Item not found")
        return self.row.copy()

    async def write(self, connection, actor, household, item_id, old, fields, action):
        self.row.update(fields)
        self.row["revision"] += 1
        if self.fail:
            raise RuntimeError("activity insert failed")
        self.writes.append(action)
        return self.row.copy()


@pytest.mark.parametrize(
    ("quantity", "minimum", "expected"),
    [
        ("0", None, "out_of_stock"),
        ("1", "1", "low_stock"),
        ("0.5", "1", "low_stock"),
        ("2", "1", "available"),
        ("2", None, "available"),
    ],
)
def test_stock_boundaries(quantity, minimum, expected):
    assert stock_status(Decimal(quantity), Decimal(minimum) if minimum else None) == expected


def test_absolute_quantity_requires_revision_and_decimal_bounds():
    with pytest.raises(ValidationError):
        InventoryQuantityUpdate(operation="set", amount="2")
    for amount in ("-1", "NaN", "0.0001", "1000000000000"):
        with pytest.raises(ValidationError):
            InventoryQuantityUpdate(operation="increase", amount=amount)


def test_type_rules():
    valid = {k: v for k, v in item().items() if k in InventoryFields.model_fields}
    InventoryFields.model_validate(valid)
    with pytest.raises(ValidationError):
        InventoryFields.model_validate({**valid, "condition": "working"})
    with pytest.raises(ValidationError):
        InventoryFields.model_validate({**valid, "item_type": "durable"})


async def test_stale_set_and_edit_are_conflicts_without_writes():
    repo = Repository()
    service = InventoryService(repo)
    for data, action in [
        (
            InventoryQuantityUpdate(operation="set", amount="0", expected_revision=1),
            service.quantity,
        ),
        (InventoryItemUpdate(name="New", expected_revision=1), service.update),
    ]:
        with pytest.raises(AppError) as error:
            await action(USER, HOME, ITEM, data)
        assert error.value.status == 409
    assert not repo.writes and repo.row["quantity"] == Decimal("3")


async def test_relative_updates_use_current_quantity_and_reject_underflow():
    repo = Repository()
    service = InventoryService(repo)
    await service.quantity(
        USER, HOME, ITEM, InventoryQuantityUpdate(operation="increase", amount="0.125")
    )
    await service.quantity(
        USER, HOME, ITEM, InventoryQuantityUpdate(operation="decrease", amount="1")
    )
    assert repo.row["quantity"] == Decimal("2.125")
    with pytest.raises(AppError):
        await service.quantity(
            USER, HOME, ITEM, InventoryQuantityUpdate(operation="decrease", amount="3")
        )
    assert repo.row["quantity"] == Decimal("2.125")


async def test_activity_failure_rolls_back_item():
    repo = Repository()
    repo.fail = True
    with pytest.raises(RuntimeError):
        await InventoryService(repo).quantity(
            USER, HOME, ITEM, InventoryQuantityUpdate(operation="increase", amount="1")
        )
    assert repo.row["revision"] == 2 and repo.row["quantity"] == Decimal("3")


async def test_archive_restore_and_cross_household_denial():
    repo = Repository()
    service = InventoryService(repo)
    archived = await service.archive(USER, HOME, ITEM, 2)
    assert archived["deleted_at"] and archived["revision"] == 3
    restored = await service.archive(USER, HOME, ITEM, 3, restore=True)
    assert restored["deleted_at"] is None
    with pytest.raises(AppError):
        await service.archive(USER, uuid4(), ITEM, 4)
    assert repo.writes == ["archived", "restored"]


async def test_durable_conditions_and_wrong_type():
    repo = Repository()
    with pytest.raises(AppError):
        await InventoryService(repo).condition(
            USER, HOME, ITEM, InventoryConditionUpdate(condition="working", expected_revision=2)
        )
    repo.row = item(
        item_type="durable", quantity=None, unit=None, minimum_quantity=None, condition="broken"
    )
    result = await InventoryService(repo).condition(
        USER, HOME, ITEM, InventoryConditionUpdate(condition="needs_repair", expected_revision=2)
    )
    assert result["condition"] == "needs_repair"


def photo_bytes():
    buffer = io.BytesIO()
    Image.new("RGB", (8, 8), "red").save(buffer, "PNG")
    return buffer.getvalue()


def test_photo_decode_validation_and_normalization():
    result = normalize_photo(base64.b64encode(photo_bytes()).decode())
    with Image.open(io.BytesIO(result)) as image:
        assert image.format == "JPEG" and not image.getexif()
    for invalid in (
        "invalid!",
        base64.b64encode(b"<svg/>").decode(),
        base64.b64encode(photo_bytes()[:20]).decode(),
    ):
        with pytest.raises(AppError):
            normalize_photo(invalid)


def test_photo_orientation_is_applied_before_metadata_is_removed():
    buffer = io.BytesIO()
    exif = Image.Exif()
    exif[274] = 6
    exif[270] = "Private description"
    Image.new("RGB", (8, 4), "red").save(buffer, "JPEG", exif=exif)
    result = normalize_photo(base64.b64encode(buffer.getvalue()).decode())
    with Image.open(io.BytesIO(result)) as image:
        assert image.size == (4, 8) and not image.getexif()


async def test_photo_upload_uses_user_token_and_remove_cleans_unreferenced(settings):
    requests = []

    async def respond(request):
        requests.append(request)
        return httpx.Response(200, content=photo_bytes())

    repo = Repository()
    async with httpx.AsyncClient(transport=httpx.MockTransport(respond)) as client:
        photos = InventoryPhotos(repo, settings, client)
        data = InventoryPhotoUpload(
            expected_revision=2, data_base64=base64.b64encode(photo_bytes()).decode()
        )
        uploaded = await photos.upload(USER, HOME, ITEM, data, "Bearer verified-user")
        assert uploaded["photo_path"].startswith(f"{HOME}/{ITEM}/")
        await photos.read(USER, HOME, ITEM, "Bearer verified-user")
        await photos.remove(USER, HOME, ITEM, 3, "Bearer verified-user")
    assert [r.method for r in requests] == ["POST", "GET", "DELETE"]
    assert all(r.headers["Authorization"] == "Bearer verified-user" for r in requests)
    assert repo.row["photo_path"] is None


async def test_photo_storage_failure_never_attaches(settings):
    repo = Repository()
    async with httpx.AsyncClient(
        transport=httpx.MockTransport(lambda _: httpx.Response(403))
    ) as client:
        with pytest.raises(AppError):
            await InventoryPhotos(repo, settings, client).upload(
                USER,
                HOME,
                ITEM,
                InventoryPhotoUpload(
                    expected_revision=2, data_base64=base64.b64encode(photo_bytes()).decode()
                ),
                "Bearer verified-user",
            )
    assert repo.row["photo_path"] is None and repo.row["revision"] == 2


def test_inventory_api_auth_filters_and_validation(client):
    fake = AsyncMock()
    fake.list.return_value = {"items": [], "total": 0, "page": 1, "page_size": 20}
    client.app.dependency_overrides[get_inventory_service] = lambda: fake
    root = f"/api/v1/households/{HOME}/inventory"
    assert client.get(root).status_code == 401
    headers = {"Authorization": "Bearer valid-token"}
    response = client.get(root + "?archived=true&location=Pantry", headers=headers)
    assert response.status_code == 200
    filters = fake.list.call_args.args[2]
    assert filters["archived"] and filters["location"] == "Pantry"
    assert (
        client.patch(
            root + f"/{ITEM}/quantity", headers=headers, json={"operation": "set", "amount": "2"}
        ).status_code
        == 422
    )
    assert client.get(root + "?sort=sql_injection", headers=headers).status_code == 422


def test_photo_api_no_store(client):
    fake = AsyncMock()
    fake.read.return_value = {"data_base64": "", "mime_type": "image/jpeg"}
    client.app.dependency_overrides[get_photos] = lambda: fake
    response = client.get(
        f"/api/v1/households/{HOME}/inventory/{ITEM}/photo",
        headers={"Authorization": "Bearer valid-token"},
    )
    assert response.status_code == 200 and response.headers["cache-control"] == "no-store"


@pytest.mark.parametrize(
    ("method", "suffix", "body", "service_path", "status"),
    [
        (
            "POST",
            "",
            {"name": "Rice", "item_type": "consumable", "quantity": "3", "unit": "kg"},
            "create",
            201,
        ),
        ("GET", f"/{ITEM}", None, "detail", 200),
        ("PATCH", f"/{ITEM}", {"name": "Rice bag", "expected_revision": 2}, "update", 200),
        ("PATCH", f"/{ITEM}/quantity", {"operation": "increase", "amount": "1"}, "quantity", 200),
        (
            "PATCH",
            f"/{ITEM}/condition",
            {"condition": "working", "expected_revision": 2},
            "condition",
            200,
        ),
        ("DELETE", f"/{ITEM}?expected_revision=2", None, "archive", 200),
        ("POST", f"/{ITEM}/restore", {"expected_revision": 2}, "archive", 200),
    ],
)
def test_inventory_api_mutations_and_detail(client, method, suffix, body, service_path, status):
    fake = AsyncMock()
    target = fake
    for attribute in service_path.split("."):
        target = getattr(target, attribute)
    target.return_value = item(stock_status="available")
    client.app.dependency_overrides[get_inventory_service] = lambda: fake
    response = client.request(
        method,
        f"/api/v1/households/{HOME}/inventory{suffix}",
        headers={"Authorization": "Bearer valid-token"},
        **({"json": body} if body else {}),
    )
    assert response.status_code == status, response.text
    assert response.json()["household_id"] == str(HOME)
    assert target.call_args.args[0].id is not None
