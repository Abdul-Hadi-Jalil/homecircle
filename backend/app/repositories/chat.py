import base64
import json
from contextlib import asynccontextmanager
from datetime import datetime
from uuid import UUID

from psycopg import sql

from app.core.exceptions import AppError
from app.repositories.tasks import TaskRepository


def cursor_for(row):
    return (
        base64.urlsafe_b64encode(
            json.dumps(
                [row["household_id"].__str__(), row["created_at"].isoformat(), str(row["id"])]
            ).encode()
        )
        .decode()
        .rstrip("=")
    )


def parse_cursor(value, household):
    try:
        h, when, identity = json.loads(base64.urlsafe_b64decode(value + "=" * (-len(value) % 4)))
        stamp = datetime.fromisoformat(when)
        if h != str(household) or stamp.tzinfo is None:
            raise ValueError
        return stamp, UUID(identity)
    except (ValueError, TypeError, KeyError, UnicodeError):
        raise AppError(422, "invalid_cursor", "Invalid chat cursor.") from None


class ChatRepository(TaskRepository):
    @asynccontextmanager
    async def transaction(self, actor, household):
        async with super().transaction(actor, household) as c:
            # Serialize this household's chat commits so event cursors never skip
            # an earlier sequence whose transaction has not committed yet.
            await c.execute(
                "SELECT pg_advisory_xact_lock(hashtextextended(%s, 5))", (str(household),)
            )
            yield c

    async def rate(self, c, actor, household, action, limit):
        row = await (
            await c.execute(
                "INSERT INTO private.chat_rate_limits(household_id,actor_id,action,"
                "window_start,count) VALUES(%s,%s,%s,date_trunc('minute',clock_timestamp()),1) "
                "ON CONFLICT(household_id,actor_id,action) DO UPDATE SET "
                "window_start=date_trunc('minute',clock_timestamp()),count=CASE WHEN "
                "private.chat_rate_limits.window_start=date_trunc('minute',clock_timestamp()) "
                "THEN private.chat_rate_limits.count+1 ELSE 1 END RETURNING count",
                (household, actor, action),
            )
        ).fetchone()
        if row["count"] > limit:
            raise AppError(429, "rate_limited", "Too many chat actions. Try again shortly.")

    async def raw(self, c, household, message_id):
        row = await (
            await c.execute(
                "SELECT * FROM public.household_messages WHERE household_id=%s AND id=%s",
                (household, message_id),
            )
        ).fetchone()
        if not row:
            raise AppError(404, "not_found", "Message not found.")
        return row

    async def by_client(self, c, actor, household, client_id):
        return await (
            await c.execute(
                "SELECT * FROM public.household_messages WHERE household_id=%s AND "
                "sender_user_id=%s AND client_message_id=%s",
                (household, actor, client_id),
            )
        ).fetchone()

    async def message(self, c, actor, household, message_id):
        row = await self.raw(c, household, message_id)
        version = (
            await (
                await c.execute(
                    "SELECT coalesce(max(sequence),0) AS n FROM public.chat_events WHERE "
                    "household_id=%s AND (message_id=%s OR message_id=%s)",
                    (household, message_id, row["reply_to_message_id"]),
                )
            ).fetchone()
        )["n"]
        name = (
            await (
                await c.execute(
                    "SELECT public.chat_actor_name(%s,%s) AS name",
                    (household, row["sender_user_id"]),
                )
            ).fetchone()
        )["name"]
        result = {k: v for k, v in row.items() if k != "request_hash"} | {
            "sender_name": name,
            "version": version,
            "reply_preview": None,
            "task": None,
            "attachments": [],
            "reactions": [],
            "converted_tasks": [],
        }
        if row["deleted_at"]:
            return {**result, "body": None, "linked_task_id": None, "reply_to_message_id": None}
        if row["reply_to_message_id"]:
            parent = await self.raw(c, household, row["reply_to_message_id"])
            parent_name = (
                await (
                    await c.execute(
                        "SELECT public.chat_actor_name(%s,%s) AS name",
                        (household, parent["sender_user_id"]),
                    )
                ).fetchone()
            )["name"]
            result["reply_preview"] = {
                "id": parent["id"],
                "household_id": household,
                "sender_name": parent_name,
                "deleted": parent["deleted_at"] is not None,
                "body": None if parent["deleted_at"] else (parent["body"] or "")[:160],
                "message_type": parent["message_type"],
            }
        if row["linked_task_id"]:
            result["task"] = await self.task_preview(c, household, row["linked_task_id"])
        result["attachments"] = await (
            await c.execute(
                "SELECT id,household_id,message_id,uploaded_by,content_type,size_bytes FROM "
                "public.message_attachments WHERE household_id=%s AND message_id=%s AND "
                "removed_at IS NULL ORDER BY id",
                (household, message_id),
            )
        ).fetchall()
        result["reactions"] = await (
            await c.execute(
                "SELECT emoji,count(*) AS count,bool_or(user_id=%s) AS mine FROM "
                "public.message_reactions WHERE household_id=%s AND message_id=%s GROUP BY "
                "emoji ORDER BY emoji",
                (actor, household, message_id),
            )
        ).fetchall()
        conversions = await (
            await c.execute(
                "SELECT task_id FROM public.chat_task_conversions WHERE household_id=%s AND "
                "message_id=%s ORDER BY created_at",
                (household, message_id),
            )
        ).fetchall()
        result["converted_tasks"] = [
            await self.task_preview(c, household, v["task_id"]) for v in conversions
        ]
        return result

    async def task_preview(self, c, household, task_id):
        row = await (
            await c.execute(
                "SELECT id,household_id,title,task_type,priority,status,revision FROM "
                "public.household_tasks WHERE household_id=%s AND id=%s AND deleted_at IS NULL",
                (household, task_id),
            )
        ).fetchone()
        return row or {"id": task_id, "household_id": household, "unavailable": True}

    async def watermark(self, c, household):
        return (
            await (
                await c.execute(
                    "SELECT coalesce(max(sequence),0) AS n FROM public.chat_events WHERE "
                    "household_id=%s",
                    (household,),
                )
            ).fetchone()
        )["n"]

    async def listing(self, actor, household, before, after, size):
        clauses = ["household_id=%s"]
        args = [household]
        boundary = before or after
        if boundary:
            stamp, identity = parse_cursor(boundary, household)
            clauses.append("(created_at,id) " + ("<" if before else ">") + " (%s,%s)")
            args.extend([stamp, identity])
        direction = "ASC" if after else "DESC"
        async with self.transaction(actor, household) as c:
            rows = await (
                await c.execute(
                    "SELECT id,household_id,created_at FROM public.household_messages WHERE "
                    + " AND ".join(clauses)
                    + " ORDER BY created_at "
                    + direction
                    + ",id "
                    + direction
                    + " LIMIT %s",
                    (*args, size + 1),
                )
            ).fetchall()
            more = len(rows) > size
            rows = rows[:size]
            if not after:
                rows.reverse()
            items = [await self.message(c, actor, household, r["id"]) for r in rows]
            return {
                "items": items,
                "has_more": more,
                "older_cursor": cursor_for(rows[0]) if rows else None,
                "after_cursor": cursor_for(rows[-1]) if rows else None,
                "watermark": await self.watermark(c, household),
            }

    async def changes(self, actor, household, after, size):
        async with self.transaction(actor, household) as c:
            events = await (
                await c.execute(
                    "SELECT sequence,message_id FROM public.chat_events WHERE household_id=%s "
                    "AND sequence>%s ORDER BY sequence LIMIT %s",
                    (household, after, size + 1),
                )
            ).fetchall()
            more = len(events) > size
            events = events[:size]
            identities = list(dict.fromkeys(e["message_id"] for e in events))
            return {
                "items": [await self.message(c, actor, household, i) for i in identities],
                "after": events[-1]["sequence"] if events else after,
                "has_more": more,
            }

    async def write_message(self, c, household, message_id, fields):
        sets = sql.SQL(",").join(sql.SQL("{}=%s").format(sql.Identifier(k)) for k in fields)
        await c.execute(
            sql.SQL(
                "UPDATE public.household_messages SET {} WHERE household_id=%s AND id=%s"
            ).format(sets),
            (*fields.values(), household, message_id),
        )

    async def upload(self, c, household, attachment_id, actor=None):
        row = await (
            await c.execute(
                "SELECT * FROM private.chat_uploads WHERE household_id=%s AND id=%s FOR UPDATE",
                (household, attachment_id),
            )
        ).fetchone()
        if not row or (actor is not None and row["actor_id"] != actor):
            raise AppError(404, "not_found", "Image upload not found.")
        return row
