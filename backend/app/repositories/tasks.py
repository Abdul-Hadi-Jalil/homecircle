from contextlib import asynccontextmanager

from psycopg import sql
from psycopg.types.json import Jsonb

from app.core.exceptions import AppError
from app.db.pool import user_transaction
from app.repositories.inventory import snapshot

SELECT = (
    "SELECT t.*,public.task_actor_name(t.household_id,t.created_by) AS creator_name,"
    "public.task_actor_name(t.household_id,t.assigned_to) AS assignee_name,"
    "i.name AS linked_inventory_name,i.item_type AS linked_inventory_type "
    "FROM public.household_tasks t "
    "LEFT JOIN public.inventory_items i ON i.household_id=t.household_id "
    "AND i.id=t.linked_inventory_item_id "
)
SORTS = {
    "priority": "CASE WHEN t.status IN ('completed','cancelled') THEN 1 ELSE 0 END, "
    "CASE t.priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 "
    "WHEN 'normal' THEN 2 ELSE 3 END,t.due_date NULLS LAST,t.updated_at DESC,t.id",
    "due_date": "t.due_date NULLS LAST,t.id",
    "updated": "t.updated_at DESC,t.id",
    "created": "t.created_at DESC,t.id",
}


class TaskRepository:
    def __init__(self, pool):
        self.pool = pool

    @asynccontextmanager
    async def transaction(self, actor, household):
        async with user_transaction(self.pool, actor) as c:
            row = await (
                await c.execute(
                    "SELECT public.lock_inventory_household(%s) AS allowed", (household,)
                )
            ).fetchone()
            if not row or not row["allowed"]:
                raise AppError(404, "not_found", "Household not found.")
            yield c

    async def task(self, c, household, task_id, *, lock=False, archived=False):
        query = SELECT + "WHERE t.household_id=%s AND t.id=%s "
        if not archived:
            query += "AND t.deleted_at IS NULL "
        if lock:
            query += "FOR UPDATE OF t"
        row = await (await c.execute(query, (household, task_id))).fetchone()
        if not row:
            raise AppError(404, "not_found", "Task not found.")
        return row

    async def detail(self, actor, household, task_id):
        async with self.transaction(actor, household) as c:
            return await self.task(c, household, task_id, archived=True)

    async def list(self, actor, household, filters):
        clauses = [
            "t.household_id=%s",
            "t.deleted_at IS NOT NULL" if filters.get("archived") else "t.deleted_at IS NULL",
        ]
        args = [household]
        for key, column in [
            ("task_type", "task_type"),
            ("status", "status"),
            ("priority", "priority"),
            ("assigned_to", "assigned_to"),
            ("linked_inventory", "linked_inventory_item_id"),
        ]:
            if filters.get(key) is not None:
                clauses.append(f"t.{column}=%s")
                args.append(filters[key])
        if filters.get("assignment") == "me":
            clauses.append("t.assigned_to=%s")
            args.append(actor)
        elif filters.get("assignment") == "unassigned":
            clauses.append("t.assigned_to IS NULL")
        for key, expression in [("due_before", "t.due_date<=%s"), ("due_after", "t.due_date>=%s")]:
            if filters.get(key):
                clauses.append(expression)
                args.append(filters[key])
        if filters.get("overdue"):
            clauses.append("t.due_date<%s AND t.status NOT IN ('completed','cancelled')")
            args.append(filters["as_of"])
        if filters.get("search"):
            term = filters["search"].replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            clauses.append("(t.title ILIKE %s ESCAPE '\\' OR t.description ILIKE %s ESCAPE '\\')")
            args.extend(["%" + term + "%"] * 2)
        where = " WHERE " + " AND ".join(clauses)
        page, size = filters.get("page", 1), filters.get("page_size", 20)
        async with self.transaction(actor, household) as c:
            rows = await (
                await c.execute(
                    SELECT
                    + where
                    + " ORDER BY "
                    + SORTS[filters.get("sort", "priority")]
                    + " LIMIT %s OFFSET %s",
                    (*args, size, (page - 1) * size),
                )
            ).fetchall()
            total = (
                await (
                    await c.execute(
                        "SELECT count(*) AS n FROM public.household_tasks t" + where, args
                    )
                ).fetchone()
            )["n"]
            return {"items": rows, "total": total, "page": page, "page_size": size}

    async def summary(self, actor, household, as_of):
        async with self.transaction(actor, household) as c:
            return await (
                await c.execute(
                    "SELECT count(*) AS total,count(*) FILTER(WHERE status='open') AS open,"
                    "count(*) FILTER(WHERE status='in_progress') AS in_progress,"
                    "count(*) FILTER(WHERE status='blocked') AS blocked,"
                    "count(*) FILTER(WHERE status='completed') AS completed,"
                    "count(*) FILTER(WHERE status='cancelled') AS cancelled,"
                    "count(*) FILTER(WHERE due_date<%s "
                    "AND status NOT IN ('completed','cancelled')) AS overdue "
                    "FROM public.household_tasks WHERE household_id=%s AND deleted_at IS NULL",
                    (as_of, household),
                )
            ).fetchone()

    async def insert(self, c, table, fields):
        query = sql.SQL("INSERT INTO public.{} ({}) VALUES ({}) RETURNING *").format(
            sql.Identifier(table),
            sql.SQL(",").join(map(sql.Identifier, fields)),
            sql.SQL(",").join(sql.Placeholder() for _ in fields),
        )
        return await (await c.execute(query, list(fields.values()))).fetchone()

    async def event(self, c, actor, household, task_id, action, changes):
        await c.execute(
            "INSERT INTO public.task_activity(household_id,task_id,actor_user_id,action,changes) "
            "VALUES(%s,%s,%s,%s,%s)",
            (household, task_id, actor, action, Jsonb(changes)),
        )

    async def create(self, actor, household, fields):
        async with self.transaction(actor, household) as c:
            row = await self.insert(
                c,
                "household_tasks",
                {**fields, "household_id": household, "created_by": actor, "updated_by": actor},
            )
            await self.event(c, actor, household, row["id"], "created", snapshot(fields))
            return await self.task(c, household, row["id"])

    async def write(self, c, actor, household, task_id, fields):
        values = {**fields, "updated_by": actor}
        sets = sql.SQL(",").join(sql.SQL("{}=%s").format(sql.Identifier(k)) for k in values)
        await c.execute(
            sql.SQL("UPDATE public.household_tasks SET {} WHERE household_id=%s AND id=%s").format(
                sets
            ),
            (*values.values(), household, task_id),
        )
        return await self.task(c, household, task_id, archived=True)

    async def is_admin(self, c, household):
        return (
            await (
                await c.execute("SELECT private.is_admin(%s) AS allowed", (household,))
            ).fetchone()
        )["allowed"]

    async def comment(self, c, household, task_id, comment_id):
        row = await (
            await c.execute(
                "SELECT * FROM public.task_comments WHERE household_id=%s AND task_id=%s AND id=%s "
                "AND deleted_at IS NULL FOR UPDATE",
                (household, task_id, comment_id),
            )
        ).fetchone()
        if not row:
            raise AppError(404, "not_found", "Comment not found.")
        return row

    async def comments(self, actor, household, task_id, page, size):
        async with self.transaction(actor, household) as c:
            await self.task(c, household, task_id, archived=True)
            rows = await (
                await c.execute(
                    "SELECT c.*,public.task_actor_name(c.household_id,c.author_user_id) "
                    "AS author_name "
                    "FROM public.task_comments c WHERE c.household_id=%s AND c.task_id=%s "
                    "AND c.deleted_at IS NULL ORDER BY c.created_at,c.id LIMIT %s OFFSET %s",
                    (household, task_id, size, (page - 1) * size),
                )
            ).fetchall()
            return {"items": rows, "page": page, "page_size": size}

    async def activity(self, actor, household, task_id, page, size):
        async with self.transaction(actor, household) as c:
            await self.task(c, household, task_id, archived=True)
            rows = await (
                await c.execute(
                    "SELECT a.*,public.task_actor_name(a.household_id,a.actor_user_id) "
                    "AS actor_name "
                    "FROM public.task_activity a WHERE a.household_id=%s AND a.task_id=%s "
                    "ORDER BY a.created_at DESC,a.id LIMIT %s OFFSET %s",
                    (household, task_id, size, (page - 1) * size),
                )
            ).fetchall()
            return {"items": rows, "page": page, "page_size": size}

    async def attachments(self, actor, household, task_id, page, size):
        async with self.transaction(actor, household) as c:
            await self.task(c, household, task_id, archived=True)
            rows = await (
                await c.execute(
                    "SELECT a.* FROM public.task_attachments a "
                    "WHERE a.household_id=%s AND a.task_id=%s "
                    "AND a.deleted_at IS NULL AND (a.comment_id IS NULL OR EXISTS("
                    "SELECT 1 FROM public.task_comments c "
                    "WHERE c.id=a.comment_id AND c.task_id=a.task_id "
                    "AND c.household_id=a.household_id AND c.deleted_at IS NULL)) "
                    "ORDER BY a.created_at,a.id LIMIT %s OFFSET %s",
                    (household, task_id, size, (page - 1) * size),
                )
            ).fetchall()
            return {"items": rows, "page": page, "page_size": size}

    async def attachment(self, c, household, task_id, attachment_id):
        row = await (
            await c.execute(
                "SELECT a.* FROM public.task_attachments a "
                "WHERE a.household_id=%s AND a.task_id=%s "
                "AND a.id=%s AND a.deleted_at IS NULL AND (a.comment_id IS NULL OR EXISTS("
                "SELECT 1 FROM public.task_comments c "
                "WHERE c.id=a.comment_id AND c.task_id=a.task_id "
                "AND c.household_id=a.household_id AND c.deleted_at IS NULL))",
                (household, task_id, attachment_id),
            )
        ).fetchone()
        if not row:
            raise AppError(404, "not_found", "Attachment not found.")
        return row
