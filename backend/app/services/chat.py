import hashlib
import json
from contextlib import asynccontextmanager
from datetime import UTC, datetime

from psycopg.errors import CheckViolation, ForeignKeyViolation

from app.core.exceptions import AppError
from app.repositories.shopping import ShoppingRepository
from app.repositories.tasks import TaskRepository
from app.services.shopping import ShoppingService
from app.services.tasks import TaskService, check_revision


def digest(data):
    return hashlib.sha256(
        json.dumps(data, sort_keys=True, default=str, ensure_ascii=False).encode()
    ).hexdigest()


class BoundTransaction:
    def __init__(self, c, actor, household, pool=None):
        self.c, self.actor, self.household, self.pool = c, actor, household, pool

    @asynccontextmanager
    async def transaction(self, actor, household):
        if actor != self.actor or household != self.household:
            raise AppError(403, "forbidden", "Invalid task scope.")
        yield self.c


class BoundTasks(BoundTransaction, TaskRepository):
    pass


class BoundShopping(BoundTransaction, ShoppingRepository):
    pass


class ChatService:
    def __init__(self, repository, settings, photos=None):
        self.repository, self.settings, self.photos = repository, settings, photos

    async def send(self, user, household, data, token=None):
        fingerprint = digest(data.model_dump())
        try:
            async with self.repository.transaction(user.id, household) as c:
                prior = await self.repository.by_client(
                    c, user.id, household, data.client_message_id
                )
                if prior:
                    if prior["request_hash"] != fingerprint:
                        raise AppError(
                            409,
                            "idempotency_conflict",
                            "This send ID belongs to an earlier message. Retry the original "
                            "message.",
                        )
                    return await self.repository.message(c, user.id, household, prior["id"]), False
                await self.repository.rate(
                    c, user.id, household, "send", self.settings.chat_message_rate
                )
                if data.reply_to_message_id:
                    await self.repository.raw(c, household, data.reply_to_message_id)
                if data.linked_task_id:
                    preview = await self.repository.task_preview(c, household, data.linked_task_id)
                    if preview.get("unavailable"):
                        raise AppError(404, "not_found", "Task is unavailable in this household.")
                uploads = []
                for attachment_id in data.attachment_ids:
                    upload = await self.repository.upload(c, household, attachment_id, user.id)
                    if (
                        not upload["finalized"]
                        or upload.get("abandoned")
                        or upload["client_message_id"] != data.client_message_id
                        or upload["expires_at"] < datetime.now(UTC)
                    ):
                        raise AppError(
                            422, "invalid_attachment", "Image is not finalized for this message."
                        )
                    await self.photos.verify(upload, token)
                    uploads.append(upload)
                fields = data.model_dump(exclude={"attachment_ids"})
                row = await self.repository.insert(
                    c,
                    "household_messages",
                    {
                        **fields,
                        "household_id": household,
                        "sender_user_id": user.id,
                        "request_hash": fingerprint,
                    },
                )
                for upload in uploads:
                    await self.repository.insert(
                        c,
                        "message_attachments",
                        {
                            "id": upload["id"],
                            "household_id": household,
                            "message_id": row["id"],
                            "uploaded_by": user.id,
                            "storage_path": upload["storage_path"],
                            "content_type": "image/jpeg",
                            "size_bytes": upload["size_bytes"],
                        },
                    )
                return await self.repository.message(c, user.id, household, row["id"]), True
        except (CheckViolation, ForeignKeyViolation):
            raise AppError(
                422, "invalid_reference", "Reply, task or image is unavailable in this household."
            ) from None

    async def detail(self, user, household, message_id):
        async with self.repository.transaction(user.id, household) as c:
            return await self.repository.message(c, user.id, household, message_id)

    async def own(self, c, user, household, message_id, expected):
        old = await self.repository.raw(c, household, message_id)
        if old["sender_user_id"] != user.id:
            raise AppError(403, "forbidden", "Only the sender can change this message.")
        check_revision(old, expected)
        if old["deleted_at"]:
            raise AppError(409, "message_deleted", "This message has been deleted.")
        return old

    async def edit(self, user, household, message_id, data):
        async with self.repository.transaction(user.id, household) as c:
            await self.own(c, user, household, message_id, data.expected_revision)
            await self.repository.rate(
                c, user.id, household, "edit", self.settings.chat_message_rate
            )
            await self.repository.write_message(
                c, household, message_id, {"body": data.body, "edited_at": datetime.now(UTC)}
            )
            return await self.repository.message(c, user.id, household, message_id)

    async def delete(self, user, household, message_id, expected):
        paths = []
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.raw(c, household, message_id)
            if old["sender_user_id"] != user.id:
                raise AppError(403, "forbidden", "Only the sender can delete this message.")
            if old["deleted_at"]:
                return await self.repository.message(c, user.id, household, message_id), []
            check_revision(old, expected)
            await self.repository.rate(
                c, user.id, household, "delete", self.settings.chat_message_rate
            )
            paths = await (
                await c.execute(
                    "SELECT storage_path FROM public.message_attachments WHERE household_id=%s "
                    "AND message_id=%s",
                    (household, message_id),
                )
            ).fetchall()
            await self.repository.write_message(
                c, household, message_id, {"deleted_at": datetime.now(UTC)}
            )
            result = await self.repository.message(c, user.id, household, message_id)
        return result, paths

    async def react(self, user, household, message_id, emoji, remove=False):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.raw(c, household, message_id)
            if old["deleted_at"]:
                raise AppError(409, "message_deleted", "This message has been deleted.")
            await self.repository.rate(
                c, user.id, household, "reaction", self.settings.chat_reaction_rate
            )
            if remove:
                await c.execute(
                    "DELETE FROM public.message_reactions WHERE household_id=%s AND "
                    "message_id=%s AND user_id=%s AND emoji=%s",
                    (household, message_id, user.id, emoji),
                )
            else:
                await c.execute(
                    "INSERT INTO public.message_reactions(household_id,message_id,user_id,"
                    "emoji) VALUES(%s,%s,%s,%s) ON CONFLICT(household_id,message_id,user_id,"
                    "emoji) DO NOTHING",
                    (household, message_id, user.id, emoji),
                )
            return await self.repository.message(c, user.id, household, message_id)

    async def convert(self, user, household, message_id, data):
        creation = data.creation()
        fingerprint = digest(
            {"message_id": message_id, "task_type": data.task_type, "fields": creation.model_dump()}
        )
        async with self.repository.transaction(user.id, household) as c:
            bound = (
                BoundShopping(c, user.id, household, self.repository.pool)
                if data.task_type == "shopping"
                else BoundTasks(c, user.id, household, self.repository.pool)
            )
            service = ShoppingService(bound) if data.task_type == "shopping" else TaskService(bound)
            prior = await (
                await c.execute(
                    "SELECT * FROM public.chat_task_conversions WHERE household_id=%s AND "
                    "actor_id=%s AND client_request_id=%s",
                    (household, user.id, data.client_request_id),
                )
            ).fetchone()
            if prior:
                if prior["request_hash"] != fingerprint:
                    raise AppError(
                        409,
                        "idempotency_conflict",
                        "This conversion ID belongs to an earlier request.",
                    )
                return await service.detail(user, household, prior["task_id"])
            old = await self.repository.raw(c, household, message_id)
            check_revision(old, data.expected_revision)
            if old["deleted_at"]:
                raise AppError(409, "message_deleted", "This message has been deleted.")
            await self.repository.rate(c, user.id, household, "convert", 20)
            task = await service.create(user, household, creation)
            await self.repository.insert(
                c,
                "chat_task_conversions",
                {
                    "household_id": household,
                    "message_id": message_id,
                    "actor_id": user.id,
                    "client_request_id": data.client_request_id,
                    "task_id": task["id"],
                    "request_hash": fingerprint,
                },
            )
            return task
