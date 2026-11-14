import base64
import json
from contextlib import asynccontextmanager
from datetime import datetime
from uuid import UUID

from psycopg import sql

from app.core.exceptions import AppError
from app.db.pool import user_transaction
from app.repositories.tasks import TaskRepository


def encode_cursor(row, scope):
    return (
        base64.urlsafe_b64encode(
            json.dumps([scope, row["created_at"].isoformat(), str(row["id"])]).encode()
        )
        .decode()
        .rstrip("=")
    )


def decode_cursor(value, scope):
    try:
        binding, stamp, identity = json.loads(
            base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))
        )
        when = datetime.fromisoformat(stamp)
        if binding != scope or when.tzinfo is None:
            raise ValueError
        return when, UUID(identity)
    except (ValueError, TypeError, UnicodeError, KeyError):
        raise AppError(422, "invalid_cursor", "Invalid page cursor.") from None


class HubRepository(TaskRepository):
    @asynccontextmanager
    async def notification_transaction(self, actor, household=None):
        if household:
            async with self.transaction(actor, household) as c:
                yield c
        else:
            async with user_transaction(self.pool, actor) as c:
                yield c

    async def dashboard(self, actor, household):
        async with self.transaction(actor, household) as c:
            row = await (
                await c.execute(DASHBOARD_SQL, {"home": household, "actor": actor})
            ).fetchone()
            return row["result"]

    async def zone(self, actor, household, zone):
        async with self.transaction(actor, household) as c:
            if not await self.is_admin(c, household):
                raise AppError(403, "forbidden", "Household administrator required.")
            valid = await (
                await c.execute("SELECT 1 FROM pg_timezone_names WHERE name=%s", (zone,))
            ).fetchone()
            if not valid:
                raise AppError(422, "validation_error", "Unknown IANA time zone.")
            await c.execute(
                "UPDATE public.households SET time_zone=%s WHERE id=%s", (zone, household)
            )
            return {"time_zone": zone}

    async def activity(self, actor, household, category, event_type, start, end, cursor, size):
        clauses, args = ["household_id=%s"], [household]
        scope = [str(household), category, event_type, str(start), str(end)]
        for expression, value in [
            ("category=%s", category),
            ("event_type=%s", event_type),
            ("created_at>=%s", start),
            ("created_at<%s", end),
        ]:
            if value is not None:
                clauses.append(expression)
                args.append(value)
        if cursor:
            clauses.append("(created_at,id)<(%s,%s)")
            args.extend(decode_cursor(cursor, scope))
        async with self.transaction(actor, household) as c:
            rows = await (
                await c.execute(
                    "SELECT * FROM public.household_activity_events WHERE "
                    + " AND ".join(clauses)
                    + " ORDER BY created_at DESC,id DESC LIMIT %s",
                    (*args, size + 1),
                )
            ).fetchall()
        return self.page(rows, size, scope)

    @staticmethod
    def page(rows, size, scope):
        more = len(rows) > size
        rows = rows[:size]
        return {
            "items": rows,
            "cursor": encode_cursor(rows[-1], scope) if more else None,
            "has_more": more,
        }

    async def notifications(self, actor, household, unread, cursor, size):
        clauses, args = ["recipient_user_id=%s", "dismissed_at IS NULL"], [actor]
        scope = [str(actor), str(household), unread]
        if household:
            clauses.append("household_id=%s")
            args.append(household)
        if unread:
            clauses.append("read_at IS NULL")
        if cursor:
            clauses.append("(created_at,id)<(%s,%s)")
            args.extend(decode_cursor(cursor, scope))
        async with self.notification_transaction(actor, household) as c:
            rows = await (
                await c.execute(
                    "SELECT * FROM public.user_notifications WHERE "
                    + " AND ".join(clauses)
                    + " ORDER BY created_at DESC,id DESC LIMIT %s",
                    (*args, size + 1),
                )
            ).fetchall()
        return self.page(rows, size, scope)

    async def unread(self, actor, household):
        async with self.notification_transaction(actor, household) as c:
            row = await (
                await c.execute(
                    "SELECT count(*) AS count FROM public.user_notifications WHERE "
                    "recipient_user_id=%s AND (%s::uuid IS NULL OR household_id=%s) AND "
                    "read_at IS NULL AND dismissed_at IS NULL",
                    (actor, household, household),
                )
            ).fetchone()
            return row

    async def notification(self, actor, identity, action=None):
        async with self.notification_transaction(actor) as c:
            row = await (
                await c.execute(
                    "SELECT * FROM public.user_notifications WHERE id=%s AND recipient_user_id=%s",
                    (identity, actor),
                )
            ).fetchone()
            if not row:
                raise AppError(404, "not_found", "Notification is unavailable.")
            # Hold the existing membership lock while changing recipient state.
            allowed = await (
                await c.execute(
                    "SELECT public.lock_inventory_household(%s) AS ok", (row["household_id"],)
                )
            ).fetchone()
            if not allowed["ok"]:
                raise AppError(404, "not_found", "Notification is unavailable.")
            if action:
                column = "read_at" if action == "read" else "dismissed_at"
                row = await (
                    await c.execute(
                        sql.SQL(
                            "UPDATE public.user_notifications SET {}=coalesce({},"
                            "clock_timestamp()) WHERE id=%s AND recipient_user_id=%s RETURNING "
                            "*"
                        ).format(sql.Identifier(column), sql.Identifier(column)),
                        (identity, actor),
                    )
                ).fetchone()
            return row

    async def read_all(self, actor, household):
        async with self.notification_transaction(actor, household) as c:
            result = await c.execute(
                "UPDATE public.user_notifications SET read_at=clock_timestamp() WHERE "
                "recipient_user_id=%s AND (%s::uuid IS NULL OR household_id=%s) AND read_at IS "
                "NULL AND dismissed_at IS NULL",
                (actor, household, household),
            )
            return {"updated": result.rowcount}

    async def preferences(self, actor, household, fields=None):
        async with self.transaction(actor, household) as c:
            if fields:
                values = {"user_id": actor, "household_id": household, **fields}
                await c.execute(
                    sql.SQL(
                        "INSERT INTO public.notification_preferences ({}) VALUES ({}) ON "
                        "CONFLICT(user_id,household_id) DO UPDATE SET {},"
                        "updated_at=clock_timestamp()"
                    ).format(
                        sql.SQL(",").join(map(sql.Identifier, values)),
                        sql.SQL(",").join(sql.Placeholder() for _ in values),
                        sql.SQL(",").join(
                            sql.SQL("{}=excluded.{}").format(sql.Identifier(k), sql.Identifier(k))
                            for k in fields
                        ),
                    ),
                    list(values.values()),
                )
            row = await (
                await c.execute(
                    "SELECT * FROM public.notification_preferences WHERE user_id=%s AND "
                    "household_id=%s",
                    (actor, household),
                )
            ).fetchone()
            return row or {"user_id": actor, "household_id": household}

    async def register(self, actor, data):
        async with self.notification_transaction(actor) as c:
            return await (
                await c.execute(
                    "SELECT public.register_fcm_device(%s,%s,%s) AS id",
                    (data.token, data.device_identifier, data.platform),
                )
            ).fetchone()

    async def revoke(self, actor, installation):
        async with self.notification_transaction(actor) as c:
            await c.execute("SELECT public.revoke_fcm_device(%s)", (installation,))
            return {"revoked": True}


# All cards and counts share one statement snapshot. Only active records enter the CTEs.
# Stable attention rank: urgent+overdue, urgent, high+overdue, overdue, high, stock,
# normal, low; due date, updated_at and UUID break ties. One row per entity.
DASHBOARD_SQL = """
WITH home AS (SELECT id,name,time_zone,(clock_timestamp() AT TIME ZONE time_zone)::date AS today
 FROM public.households WHERE id=%(home)s),
all_tasks AS (SELECT * FROM public.household_tasks
 WHERE household_id=%(home)s AND deleted_at IS NULL),
t AS (SELECT * FROM all_tasks WHERE status IN ('open','in_progress','blocked')),
i AS (SELECT * FROM public.inventory_items WHERE household_id=%(home)s AND deleted_at IS NULL),
cards AS (SELECT id,household_id,case when task_type='shopping' then 'shopping' else 'task' end
AS entity_type,
 title,task_type,priority,status,due_date,public.task_actor_name(household_id,assigned_to) AS
assignee_name,
 CASE WHEN priority='urgent' AND due_date<(SELECT today FROM home) THEN 0 WHEN priority='urgent'
THEN 1
 WHEN priority='high' AND due_date<(SELECT today FROM home) THEN 2 WHEN due_date<(SELECT today
FROM home) THEN 3
 WHEN priority='high' THEN 4 WHEN priority='normal' THEN 6 ELSE 7 END AS rank,updated_at FROM t
 UNION ALL SELECT id,household_id,'inventory',name,null,null,
 case when item_type='durable' then condition when quantity=0 then 'out_of_stock' else
'low_stock' end,
 null,null,5,updated_at FROM i
 WHERE (item_type='consumable' AND (quantity=0 OR (quantity>0 AND quantity<=minimum_quantity)))
 OR (item_type='durable' AND condition IN ('broken','needs_repair')))
SELECT jsonb_build_object('household',(SELECT to_jsonb(h)-'today' FROM home h),
 'as_of_date',(SELECT today FROM home),'refreshed_at',clock_timestamp(),
 'has_records',(SELECT count(*) FROM all_tasks)+(SELECT count(*) FROM i)>0,
 'summary',jsonb_build_object('pending_tasks',(SELECT count(*) FROM t WHERE task_type<>'shopping'),
 'urgent_issues',(SELECT count(*) FROM t WHERE task_type<>'shopping' AND priority='urgent'),
 'shopping_items',(SELECT count(*) FROM t WHERE task_type='shopping'),
 'low_stock_items',(SELECT count(*) FROM i WHERE item_type='consumable' AND quantity>0 AND
quantity<=minimum_quantity),
 'out_of_stock_items',(SELECT count(*) FROM i WHERE item_type='consumable' AND quantity=0),
 'overdue_tasks',(SELECT count(*) FROM t WHERE due_date<(SELECT today FROM home)),
 'my_tasks',(SELECT count(*) FROM t WHERE assigned_to=%(actor)s)),
 'needs_attention',coalesce((SELECT jsonb_agg(to_jsonb(c)-'updated_at' ORDER BY rank,due_date
NULLS LAST,updated_at DESC,id)
 FROM (SELECT * FROM cards ORDER BY rank,due_date NULLS LAST,updated_at DESC,id LIMIT
8)c),'[]'::jsonb),
 'upcoming_tasks',coalesce((SELECT jsonb_agg(to_jsonb(c)-'updated_at' ORDER BY due_date,rank,id)
FROM
 (SELECT * FROM cards WHERE entity_type<>'inventory' AND due_date BETWEEN (SELECT today FROM home)
 AND (SELECT today+7 FROM home) ORDER BY due_date,rank,id LIMIT 5)c),'[]'::jsonb),
 'recent_activity',coalesce((SELECT jsonb_agg(to_jsonb(a) ORDER BY created_at DESC,id DESC) FROM
 (SELECT * FROM public.household_activity_events WHERE household_id=%(home)s ORDER BY created_at
DESC,id DESC LIMIT 5)a),'[]'::jsonb),
 'unread_notifications',(SELECT count(*) FROM public.user_notifications WHERE household_id=%(home)s
 AND recipient_user_id=%(actor)s AND read_at IS NULL AND dismissed_at IS NULL)) AS result
"""
