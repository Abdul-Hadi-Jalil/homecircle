import hashlib
from datetime import UTC, datetime, timedelta

import psycopg
from starlette.concurrency import run_in_threadpool

from app.core.exceptions import AppError
from app.services.inventory_photos import InventoryPhotos, normalize_photo


class ChatPhotos(InventoryPhotos):
    async def cleanup(self, user, household, path, token):
        try:
            async with self.repository.transaction(user.id, household) as c:
                await c.execute(
                    "UPDATE private.chat_uploads SET finalized=true,abandoned=true WHERE "
                    "household_id=%s AND actor_id=%s AND storage_path=%s AND NOT EXISTS(SELECT "
                    "1 FROM public.message_attachments a JOIN public.household_messages m ON "
                    "m.id=a.message_id AND m.household_id=a.household_id WHERE "
                    "a.storage_path=%s AND a.removed_at IS NULL AND m.deleted_at IS NULL)",
                    (household, user.id, path, path),
                )
            await self.storage("DELETE", f"chat-attachments/{path}", token)
        except (AppError, psycopg.Error):
            pass  # Retention retries private orphan cleanup through Storage API.

    async def upload_image(self, user, household, data, token):
        input_hash = hashlib.sha256(data.data_base64.encode()).hexdigest()
        async with self.repository.transaction(user.id, household) as c:
            prior = await (
                await c.execute(
                    "SELECT * FROM private.chat_uploads WHERE id=%s AND household_id=%s AND "
                    "actor_id=%s",
                    (data.attachment_id, household, user.id),
                )
            ).fetchone()
            if prior:
                if (
                    prior["input_hash"] != input_hash
                    or prior["client_message_id"] != data.client_message_id
                ):
                    raise AppError(
                        409, "idempotency_conflict", "This image ID belongs to a different upload."
                    )
                if prior.get("abandoned"):
                    raise AppError(
                        409, "upload_failed", "Select the image again to retry the upload."
                    )
                if prior["finalized"]:
                    return {
                        "id": prior["id"],
                        "household_id": household,
                        "client_message_id": prior["client_message_id"],
                        "content_type": "image/jpeg",
                        "size_bytes": prior["size_bytes"],
                    }
                raise AppError(
                    409,
                    "upload_in_progress",
                    "This upload has not finalized. Retry with a new image selection.",
                )
            await self.repository.rate(
                c, user.id, household, "upload", self.settings.chat_upload_rate
            )
        content = await run_in_threadpool(
            normalize_photo, data.data_base64, max_bytes=self.settings.chat_image_max_bytes
        )
        path = f"{household}/{user.id}/{data.attachment_id}.jpg"
        async with self.repository.transaction(user.id, household) as c:
            existing = await (
                await c.execute(
                    "SELECT id FROM private.chat_uploads WHERE id=%s", (data.attachment_id,)
                )
            ).fetchone()
            if existing:
                raise AppError(409, "upload_in_progress", "This upload is already being processed.")
            await c.execute(
                "INSERT INTO private.chat_uploads(id,household_id,actor_id,client_message_id,"
                "storage_path,input_hash,content_hash,size_bytes) VALUES(%s,%s,%s,%s,%s,%s,%s,"
                "%s)",
                (
                    data.attachment_id,
                    household,
                    user.id,
                    data.client_message_id,
                    path,
                    input_hash,
                    hashlib.sha256(content).hexdigest(),
                    len(content),
                ),
            )
        try:
            await self.storage("POST", f"chat-attachments/{path}", token, content)
            async with self.repository.transaction(user.id, household) as c:
                await c.execute(
                    "UPDATE private.chat_uploads SET finalized=true,expires_at=%s WHERE "
                    "household_id=%s AND id=%s AND actor_id=%s",
                    (datetime.now(UTC) + timedelta(days=1), household, data.attachment_id, user.id),
                )
        except Exception:
            await self.cleanup(user, household, path, token)
            raise
        return {
            "id": data.attachment_id,
            "household_id": household,
            "client_message_id": data.client_message_id,
            "content_type": "image/jpeg",
            "size_bytes": len(content),
        }

    async def verify(self, upload, token):
        response = await self.storage("GET", f"chat-attachments/{upload['storage_path']}", token)
        if (
            len(response.content) != upload["size_bytes"]
            or hashlib.sha256(response.content).hexdigest() != upload["content_hash"]
        ):
            raise AppError(
                422, "invalid_attachment", "The finalized image is unavailable. Select it again."
            )

    async def read_url(self, user, household, attachment_id, token):
        async with self.repository.transaction(user.id, household) as c:
            attachment = await (
                await c.execute(
                    "SELECT a.storage_path FROM public.message_attachments a JOIN "
                    "public.household_messages m ON m.household_id=a.household_id AND "
                    "m.id=a.message_id WHERE a.household_id=%s AND a.id=%s AND a.removed_at IS "
                    "NULL AND m.deleted_at IS NULL",
                    (household, attachment_id),
                )
            ).fetchone()
            if not attachment:
                raise AppError(404, "not_found", "Image is unavailable.")
            response = await self.storage(
                "POST",
                f"sign/chat-attachments/{attachment['storage_path']}",
                token,
                json_body={"expiresIn": 60},
            )
            try:
                signed = response.json()["signedURL"]
                if not isinstance(signed, str) or not signed.startswith(
                    "/object/sign/chat-attachments/"
                ):
                    raise ValueError
            except (ValueError, KeyError, TypeError):
                raise AppError(503, "photo_unavailable", "Image storage is unavailable.") from None
            return {"url": self.settings.supabase_url + "/storage/v1" + signed, "expires_in": 60}
