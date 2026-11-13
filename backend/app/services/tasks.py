from datetime import UTC, datetime

from psycopg.errors import CheckViolation, ForeignKeyViolation
from pydantic import ValidationError

from app.core.exceptions import AppError
from app.repositories.inventory import InventoryRepository, snapshot
from app.schemas.task import TaskFields


def check_revision(old, expected):
    if old["revision"] != expected:
        raise AppError(409, "revision_conflict", "This task changed. Refresh before saving again.")


def editable(old):
    if old["task_type"] == "shopping":
        raise AppError(
            409, "shopping_reserved", "Shopping tasks are reserved for a future milestone."
        )


class TaskService:
    def __init__(self, repository):
        self.repository = repository

    async def list(self, user, household, filters):
        return await self.repository.list(user.id, household, filters)

    async def detail(self, user, household, task_id):
        return await self.repository.detail(user.id, household, task_id)

    async def summary(self, user, household, as_of):
        return await self.repository.summary(user.id, household, as_of)

    async def related(self, user, household, item_id, filters):
        inventory = InventoryRepository(self.repository.pool)
        await inventory.detail(user.id, household, item_id)
        return await self.list(
            user, household, {**filters, "linked_inventory": item_id, "task_type": "repair"}
        )

    async def create(self, user, household, data):
        try:
            return await self.repository.create(user.id, household, data.model_dump())
        except (CheckViolation, ForeignKeyViolation):
            raise AppError(
                422,
                "invalid_reference",
                "Assignee or linked item is not available in this household.",
            ) from None

    async def apply(self, c, user, household, task_id, old, fields, action):
        changes = {
            k: {"before": snapshot({k: old.get(k)})[k], "after": snapshot({k: v})[k]}
            for k, v in fields.items()
            if old.get(k) != v
        }
        if not changes:
            return old
        try:
            result = await self.repository.write(c, user.id, household, task_id, fields)
        except (CheckViolation, ForeignKeyViolation):
            raise AppError(
                422, "invalid_reference", "Assignee, linked item or task fields are invalid."
            ) from None
        await self.repository.event(c, user.id, household, task_id, action, changes)
        if action == "updated":
            if "assigned_to" in changes:
                await self.repository.event(
                    c,
                    user.id,
                    household,
                    task_id,
                    "assigned" if fields["assigned_to"] else "unassigned",
                    {"assigned_to": changes["assigned_to"]},
                )
            if "priority" in changes:
                await self.repository.event(
                    c,
                    user.id,
                    household,
                    task_id,
                    "priority_changed",
                    {"priority": changes["priority"]},
                )
        return result

    async def update(self, user, household, task_id, data):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.task(c, household, task_id, lock=True)
            editable(old)
            check_revision(old, data.expected_revision)
            fields = data.model_dump(exclude_unset=True, exclude={"expected_revision"})
            try:
                TaskFields.model_validate(
                    {**{k: old[k] for k in TaskFields.model_fields}, **fields}
                )
            except ValidationError:
                raise AppError(422, "validation_error", "Invalid task fields.") from None
            return await self.apply(c, user, household, task_id, old, fields, "updated")

    async def assignment(self, user, household, task_id, data):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.task(c, household, task_id, lock=True)
            editable(old)
            check_revision(old, data.expected_revision)
            if data.operation == "claim" and old["assigned_to"] is not None:
                raise AppError(409, "already_claimed", "This task already has an assignee.")
            target = user.id if data.operation == "claim" else data.assigned_to
            action = (
                "claimed" if data.operation == "claim" else "assigned" if target else "unassigned"
            )
            return await self.apply(
                c, user, household, task_id, old, {"assigned_to": target}, action
            )

    async def priority(self, user, household, task_id, data):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.task(c, household, task_id, lock=True)
            editable(old)
            check_revision(old, data.expected_revision)
            return await self.apply(
                c, user, household, task_id, old, {"priority": data.priority}, "priority_changed"
            )

    async def status(self, user, household, task_id, data):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.task(c, household, task_id, lock=True)
            editable(old)
            check_revision(old, data.expected_revision)
            terminal = old["status"] in ("completed", "cancelled")
            if (
                terminal
                and old["status"] != data.status
                and not (data.reopen and data.status == "open")
            ):
                raise AppError(
                    409,
                    "explicit_reopen_required",
                    "Reopen this task explicitly before changing status.",
                )
            if data.reopen and not (terminal and data.status == "open"):
                raise AppError(
                    422, "invalid_transition", "Only a closed task can be reopened to Open."
                )
            if data.completion_note is not None and data.status != "completed":
                raise AppError(
                    422, "invalid_transition", "Completion notes apply only to completed tasks."
                )
            if old["status"] == data.status:
                return old
            now = datetime.now(UTC)
            fields = {
                "status": data.status,
                "completed_at": now if data.status == "completed" else None,
                "cancelled_at": now if data.status == "cancelled" else None,
                "completion_note": data.completion_note if data.status == "completed" else None,
            }
            action = (
                "reopened"
                if data.reopen
                else "completed"
                if data.status == "completed"
                else "cancelled"
                if data.status == "cancelled"
                else "status_changed"
            )
            # This transaction deliberately never writes inventory conditions.
            return await self.apply(c, user, household, task_id, old, fields, action)

    async def archive(self, user, household, task_id, expected, *, restore=False):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.task(c, household, task_id, lock=True, archived=True)
            editable(old)
            check_revision(old, expected)
            return await self.apply(
                c,
                user,
                household,
                task_id,
                old,
                {"deleted_at": None if restore else old["deleted_at"] or datetime.now(UTC)},
                "restored" if restore else "archived",
            )

    async def comments(self, user, household, task_id, page, size):
        return await self.repository.comments(user.id, household, task_id, page, size)

    async def comment_permission(self, c, user, household, comment):
        if comment["author_user_id"] != user.id and not await self.repository.is_admin(
            c, household
        ):
            raise AppError(
                403, "forbidden", "Only the author or an administrator can change this comment."
            )

    async def add_comment(self, user, household, task_id, data):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.task(c, household, task_id, lock=True)
            editable(old)
            check_revision(old, data.expected_revision)
            comment = await self.repository.insert(
                c,
                "task_comments",
                {
                    "household_id": household,
                    "task_id": task_id,
                    "author_user_id": user.id,
                    "body": data.body,
                },
            )
            await self.repository.write(c, user.id, household, task_id, {})
            await self.repository.event(
                c, user.id, household, task_id, "comment_added", {"comment_id": str(comment["id"])}
            )
            return comment

    async def change_comment(
        self, user, household, task_id, comment_id, expected, expected_comment, body=None
    ):
        async with self.repository.transaction(user.id, household) as c:
            old = await self.repository.task(c, household, task_id, lock=True)
            editable(old)
            check_revision(old, expected)
            comment = await self.repository.comment(c, household, task_id, comment_id)
            await self.comment_permission(c, user, household, comment)
            check_revision(comment, expected_comment)
            if body is None:
                query, value, action = "deleted_at=%s", datetime.now(UTC), "comment_deleted"
            else:
                query, value, action = "body=%s", body, "comment_edited"
            row = await (
                await c.execute(
                    "UPDATE public.task_comments SET " + query + ",updated_at=clock_timestamp(),"
                    "revision=revision+1 WHERE household_id=%s "
                    "AND task_id=%s AND id=%s RETURNING *",
                    (value, household, task_id, comment_id),
                )
            ).fetchone()
            await self.repository.write(c, user.id, household, task_id, {})
            await self.repository.event(
                c, user.id, household, task_id, action, {"comment_id": str(comment_id)}
            )
            return row

    async def activity(self, user, household, task_id, page, size):
        return await self.repository.activity(user.id, household, task_id, page, size)

    async def attachments(self, user, household, task_id, page, size):
        return await self.repository.attachments(user.id, household, task_id, page, size)
