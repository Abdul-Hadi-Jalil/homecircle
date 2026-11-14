"""Validated user-authorized Storage access; no service-role credential."""

import base64
import binascii
import io
import ssl
import warnings
from uuid import uuid4

import httpx
import psycopg
from PIL import Image, ImageOps, UnidentifiedImageError
from starlette.concurrency import run_in_threadpool

from app.core.exceptions import AppError
from app.services.inventory import revision

MAX_BYTES = 5 * 1024 * 1024
Image.MAX_IMAGE_PIXELS = 16_000_000


def normalize_photo(encoded, *, max_bytes=MAX_BYTES):
    try:
        raw = base64.b64decode(encoded, validate=True)
        if len(raw) > max_bytes:
            raise ValueError
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(raw)) as image:
                if image.format not in {"JPEG", "PNG", "WEBP"}:
                    raise ValueError
                image.load()
                if image.width * image.height > 16_000_000:
                    raise ValueError
                # A fresh RGB image drops EXIF/GPS, comments and other metadata.
                oriented = ImageOps.exif_transpose(image)
                clean = Image.new("RGB", oriented.size, "white")
                if oriented.mode == "RGBA":
                    clean.paste(oriented, mask=oriented.getchannel("A"))
                else:
                    clean.paste(oriented.convert("RGB"))
                oriented.close()
                output = io.BytesIO()
                clean.save(output, format="JPEG", quality=85)
        result = output.getvalue()
        if len(result) > max_bytes:
            raise ValueError
        return result
    except (
        ValueError,
        binascii.Error,
        OSError,
        UnidentifiedImageError,
        Image.DecompressionBombError,
        Image.DecompressionBombWarning,
    ):
        raise AppError(
            422, "invalid_photo", "Use a JPEG, PNG or WebP up to 5 MiB and 16 MP."
        ) from None


class InventoryPhotos:
    def __init__(self, repository, settings, client=None):
        self.repository = repository
        self.settings = settings
        self.client = client

    async def storage(self, method, path, token, content=None, *, json_body=None):
        headers = {"Authorization": token}
        if self.settings.supabase_publishable_key:
            headers["apikey"] = self.settings.supabase_publishable_key.get_secret_value()
        if content is not None:
            headers["Content-Type"] = "image/jpeg"
            headers["x-upsert"] = "false"
        url = f"{self.settings.supabase_url}/storage/v1/object/{path}"
        try:
            if self.client:
                response = await self.client.request(
                    method, url, headers=headers, content=content, json=json_body
                )
            else:
                async with httpx.AsyncClient(
                    timeout=20, follow_redirects=False, verify=ssl.create_default_context()
                ) as client:
                    response = await client.request(
                        method, url, headers=headers, content=content, json=json_body
                    )
            if response.status_code not in (200, 201, 204):
                raise AppError(
                    503, "photo_unavailable", "Photo storage is temporarily unavailable."
                )
            return response
        except httpx.HTTPError:
            raise AppError(
                503, "photo_unavailable", "Photo storage is temporarily unavailable."
            ) from None

    async def cleanup(self, actor, household, path, token):
        if not path:
            return
        try:
            async with self.repository.transaction(actor, household) as c:
                await c.execute(
                    "UPDATE private.inventory_uploads SET finalized=true WHERE path=%s", (path,)
                )
            # Policy permits deletion only while no inventory item references it.
            await self.storage("DELETE", f"inventory-photos/{path}", token)
            async with self.repository.transaction(actor, household) as c:
                await c.execute("DELETE FROM private.inventory_uploads WHERE path=%s", (path,))
        except (AppError, psycopg.Error):
            # Orphans remain private. A retention job can retry after revocation/outage.
            pass

    async def upload(self, user, household, item_id, data, token):
        content = await run_in_threadpool(normalize_photo, data.data_base64)
        path = f"{household}/{item_id}/{uuid4()}.jpg"
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.item(c, household, item_id, lock=True)
            revision(old, data.expected_revision)
            await c.execute(
                "INSERT INTO private.inventory_uploads(path,household_id,actor_id) "
                "VALUES(%s,%s,%s)",
                (path, household, user.id),
            )
        try:
            async with self.repository.transaction(user.id, household) as c:
                old = await self.repository.item(c, household, item_id, lock=True)
                revision(old, data.expected_revision)
                await self.storage("POST", f"inventory-photos/{path}", token, content)
                result = await self.repository.write(
                    c, user.id, household, item_id, old, {"photo_path": path}, "photo_changed"
                )
                await c.execute(
                    "UPDATE private.inventory_uploads SET finalized=true WHERE path=%s", (path,)
                )
        except Exception:
            await self.cleanup(user.id, household, path, token)
            raise
        await self.cleanup(user.id, household, old["photo_path"], token)
        return result

    async def remove(self, user, household, item_id, expected, token):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.item(c, household, item_id, lock=True)
            revision(old, expected)
            result = (
                old
                if not old["photo_path"]
                else await self.repository.write(
                    c, user.id, household, item_id, old, {"photo_path": None}, "photo_changed"
                )
            )
        await self.cleanup(user.id, household, old["photo_path"], token)
        return result

    async def read(self, user, household, item_id, token):
        async with self.repository.transaction(user.id, household) as c:
            item = await self.repository.item(c, household, item_id)
            if not item["photo_path"]:
                raise AppError(404, "not_found", "Photo not found.")
            response = await self.storage(
                "GET", f"authenticated/inventory-photos/{item['photo_path']}", token
            )
            return {
                "data_base64": base64.b64encode(response.content).decode(),
                "mime_type": "image/jpeg",
            }
