from datetime import UTC, datetime
from uuid import uuid4

import psycopg
from starlette.concurrency import run_in_threadpool

from app.core.exceptions import AppError
from app.services.inventory_photos import InventoryPhotos, normalize_photo
from app.services.tasks import TaskService, check_revision, editable


class TaskPhotos(InventoryPhotos):
    """Reuse inventory decoding and user-authorized Storage transport."""

    async def cleanup(self, actor, household, path, token):
        try:
            async with self.repository.transaction(actor, household) as c:
                await c.execute(
                    "UPDATE private.task_uploads SET finalized=true WHERE path=%s", (path,)
                )
            await self.storage("DELETE", f"repair-attachments/{path}", token)
            async with self.repository.transaction(actor, household) as c:
                await c.execute("DELETE FROM private.task_uploads WHERE path=%s", (path,))
        except (AppError, psycopg.Error):
            pass  # Private orphan; retention retries through Storage API.

    async def authorize_upload(self, c, user, household, task_id, data):
        old = await self.repository.task(c, household, task_id, lock=True)
        editable(old)
        check_revision(old, data.expected_revision)
        if data.comment_id:
            comment = await self.repository.comment(c, household, task_id, data.comment_id)
            await TaskService(self.repository).comment_permission(c, user, household, comment)
        count = (
            await (
                await c.execute(
                    "SELECT count(*) AS n FROM public.task_attachments a "
                    "WHERE a.household_id=%s AND a.task_id=%s AND a.deleted_at IS NULL "
                    "AND (a.comment_id IS NULL OR EXISTS(SELECT 1 FROM public.task_comments c "
                    "WHERE c.household_id=a.household_id AND c.task_id=a.task_id "
                    "AND c.id=a.comment_id AND c.deleted_at IS NULL))",
                    (household, task_id),
                )
            ).fetchone()
        )["n"]
        if count >= 50:
            raise AppError(
                422, "attachment_limit", "Remove an attachment before adding more (maximum 50)."
            )
        return old

    async def upload(self, user, household, task_id, data, token):
        content = await run_in_threadpool(normalize_photo, data.data_base64)
        attachment_id = uuid4()
        path = f"{household}/{task_id}/{attachment_id}.jpg"
        async with self.repository.transaction(user.id, household) as c:
            await self.authorize_upload(c, user, household, task_id, data)
            await c.execute(
                "INSERT INTO private.task_uploads(path,household_id,actor_id) VALUES(%s,%s,%s)",
                (path, household, user.id),
            )
        try:
            async with self.repository.transaction(user.id, household) as c:
                await self.authorize_upload(c, user, household, task_id, data)
                await self.storage("POST", f"repair-attachments/{path}", token, content)
                attachment = await self.repository.insert(
                    c,
                    "task_attachments",
                    {
                        "id": attachment_id,
                        "household_id": household,
                        "task_id": task_id,
                        "comment_id": data.comment_id,
                        "uploaded_by": user.id,
                        "storage_path": path,
                        "content_type": "image/jpeg",
                        "size_bytes": len(content),
                    },
                )
                await self.repository.write(c, user.id, household, task_id, {})
                await self.repository.event(
                    c,
                    user.id,
                    household,
                    task_id,
                    "attachment_added",
                    {
                        "attachment_id": str(attachment_id),
                        "comment_id": str(data.comment_id) if data.comment_id else None,
                    },
                )
                await c.execute(
                    "UPDATE private.task_uploads SET finalized=true WHERE path=%s", (path,)
                )
        except Exception:
            await self.cleanup(user.id, household, path, token)
            raise
        return attachment

    async def remove(self, user, household, task_id, attachment_id, expected, token):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.task(c, household, task_id, lock=True)
            editable(old)
            check_revision(old, expected)
            attachment = await self.repository.attachment(c, household, task_id, attachment_id)
            if attachment["uploaded_by"] != user.id and not await self.repository.is_admin(
                c, household
            ):
                raise AppError(
                    403, "forbidden", "Only the uploader or an administrator can remove a photo."
                )
            await c.execute(
                "UPDATE public.task_attachments SET deleted_at=%s "
                "WHERE household_id=%s AND task_id=%s AND id=%s",
                (datetime.now(UTC), household, task_id, attachment_id),
            )
            result = await self.repository.write(c, user.id, household, task_id, {})
            await self.repository.event(
                c,
                user.id,
                household,
                task_id,
                "attachment_removed",
                {"attachment_id": str(attachment_id)},
            )
        await self.cleanup(user.id, household, attachment["storage_path"], token)
        return result

    async def read_url(self, user, household, task_id, attachment_id, token):
        async with self.repository.transaction(user.id, household) as c:
            await self.repository.task(c, household, task_id, lock=True)
            attachment = await self.repository.attachment(c, household, task_id, attachment_id)
            response = await self.storage(
                "POST",
                f"sign/repair-attachments/{attachment['storage_path']}",
                token,
                json_body={"expiresIn": 60},
            )
            try:
                signed = response.json()["signedURL"]
                if not isinstance(signed, str) or not signed.startswith(
                    "/object/sign/repair-attachments/"
                ):
                    raise ValueError
            except (ValueError, KeyError, TypeError):
                raise AppError(
                    503, "photo_unavailable", "Photo storage is temporarily unavailable."
                ) from None
            return {"url": self.settings.supabase_url + "/storage/v1" + signed, "expires_in": 60}
