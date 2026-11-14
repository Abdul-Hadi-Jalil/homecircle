from psycopg import sql

from app.core.exceptions import AppError
from app.repositories.tasks import SORTS, TaskRepository

SELECT = (
    "SELECT t.*,d.quantity,d.unit,d.linked_inventory_item_id,d.purchase_id,d.actual_quantity,"
    "d.purchased_by,d.purchased_at,d.purchase_price,d.currency_code,d.inventory_updated_at,"
    "public.task_actor_name(t.household_id,t.created_by) AS creator_name,"
    "public.task_actor_name(t.household_id,t.assigned_to) AS assignee_name,"
    "public.task_actor_name(t.household_id,d.purchased_by) AS purchaser_name,"
    "i.name AS linked_inventory_name,i.item_type AS linked_inventory_type "
    "FROM public.household_tasks t JOIN public.shopping_item_details d "
    "ON d.task_id=t.id AND d.household_id=t.household_id "
    "LEFT JOIN public.inventory_items i ON i.id=d.linked_inventory_item_id "
    "AND i.household_id=d.household_id "
)


class ShoppingRepository(TaskRepository):
    async def item(self, c, household, task_id, *, lock=False, archived=False):
        query = SELECT + "WHERE t.household_id=%s AND t.id=%s AND t.task_type='shopping' "
        if not archived:
            query += "AND t.deleted_at IS NULL "
        if lock:
            query += "FOR UPDATE OF t,d"
        row = await (await c.execute(query, (household, task_id))).fetchone()
        if not row:
            raise AppError(404, "not_found", "Shopping request not found.")
        return row

    async def write_details(self, c, household, task_id, fields):
        if not fields:
            return
        sets = sql.SQL(",").join(sql.SQL("{}=%s").format(sql.Identifier(k)) for k in fields)
        await c.execute(
            sql.SQL(
                "UPDATE public.shopping_item_details SET {} WHERE household_id=%s AND task_id=%s"
            ).format(sets),
            (*fields.values(), household, task_id),
        )

    def scope(self, actor, household, filters):
        clauses = [
            "t.household_id=%s",
            "t.task_type='shopping'",
            "t.deleted_at IS NOT NULL" if filters.get("archived") else "t.deleted_at IS NULL",
        ]
        args = [household]
        for key, column in [
            ("priority", "t.priority"),
            ("assigned_to", "t.assigned_to"),
            ("linked_inventory_item_id", "d.linked_inventory_item_id"),
        ]:
            if filters.get(key):
                clauses.append(column + "=%s")
                args.append(filters[key])
        if filters.get("assignment") == "me":
            clauses.append("t.assigned_to=%s")
            args.append(actor)
        elif filters.get("assignment") == "unassigned":
            clauses.append("t.assigned_to IS NULL")
        if filters.get("search"):
            term = filters["search"].replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            clauses.append("(t.title ILIKE %s ESCAPE '\\' OR t.description ILIKE %s ESCAPE '\\')")
            args.extend(["%" + term + "%"] * 2)
        return clauses, args

    async def listing(self, actor, household, filters):
        clauses, args = self.scope(actor, household, filters)
        view = filters.get("view", "all")
        if view == "active":
            clauses.append("t.status IN ('open','in_progress','blocked')")
        elif view == "purchased":
            clauses.append("t.status='completed'")
        elif view == "cancelled":
            clauses.append("t.status='cancelled'")
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
                        "SELECT count(*) AS n FROM public.household_tasks t "
                        "JOIN public.shopping_item_details d ON d.task_id=t.id "
                        "AND d.household_id=t.household_id" + where,
                        args,
                    )
                ).fetchone()
            )["n"]
            return {"items": rows, "total": total, "page": page, "page_size": size}

    async def summary(self, actor, household, filters):
        clauses, args = self.scope(actor, household, filters)
        async with self.transaction(actor, household) as c:
            row = await (
                await c.execute(
                    "SELECT count(*) FILTER(WHERE t.status "
                    "IN ('open','in_progress','blocked')) AS active,"
                    "count(*) FILTER(WHERE t.status='completed') AS purchased,"
                    "count(*) FILTER(WHERE t.status IN ('open','in_progress','blocked') "
                    "AND t.priority IN ('high','urgent')) AS high_priority,"
                    "count(*) FILTER(WHERE t.status IN ('open','in_progress','blocked') "
                    "AND t.assigned_to=%s) AS assigned_to_me "
                    "FROM public.household_tasks t JOIN public.shopping_item_details d "
                    "ON d.task_id=t.id AND d.household_id=t.household_id WHERE "
                    + " AND ".join(clauses),
                    (actor, *args),
                )
            ).fetchone()
            denominator = row["active"] + row["purchased"]
            return {
                **row,
                "total": denominator,
                "completion_percentage": round(100 * row["purchased"] / denominator)
                if denominator
                else 0,
            }

    async def history(self, actor, household, filters):
        clauses, args = self.scope(actor, household, filters)
        page, size = filters.get("page", 1), filters.get("page_size", 20)
        async with self.transaction(actor, household) as c:
            rows = await (
                await c.execute(
                    "SELECT a.id,a.task_id,a.household_id,t.title,a.actor_user_id,"
                    "public.task_actor_name(a.household_id,a.actor_user_id) AS actor_name,"
                    "a.created_at,a.changes->'purchase' AS purchase "
                    "FROM public.task_activity a JOIN public.household_tasks t "
                    "ON t.id=a.task_id AND t.household_id=a.household_id "
                    "JOIN public.shopping_item_details d ON d.task_id=t.id "
                    "AND d.household_id=t.household_id "
                    "WHERE a.action='completed' AND a.changes ? 'purchase' AND "
                    + " AND ".join(clauses)
                    + " ORDER BY a.created_at DESC,a.id LIMIT %s OFFSET %s",
                    (*args, size, (page - 1) * size),
                )
            ).fetchall()
            return {"items": rows, "page": page, "page_size": size}
