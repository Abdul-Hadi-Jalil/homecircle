from contextlib import asynccontextmanager
from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from psycopg import sql
from psycopg.types.json import Jsonb

from app.core.exceptions import AppError
from app.db.pool import user_transaction

STOCK = (
    "CASE WHEN i.item_type='durable' THEN NULL WHEN i.quantity=0 THEN 'out_of_stock' "
    "WHEN i.minimum_quantity IS NOT NULL AND i.quantity<=i.minimum_quantity "
    "THEN 'low_stock' ELSE 'available' END"
)
SELECT = (
    f"SELECT i.*, c.name AS category_name, {STOCK} AS stock_status "
    "FROM public.inventory_items i LEFT JOIN public.inventory_categories c ON c.id=i.category_id "
)
SORTS = {
    "updated": "i.updated_at DESC, i.id",
    "name": "lower(i.name), i.id",
    "oldest": "i.created_at, i.id",
}


def snapshot(row):
    return {
        k: str(v) if isinstance(v, (Decimal, UUID, datetime, date)) else v
        for k, v in row.items()
        if k not in {"category_name", "stock_status", "updated_by_name"}
    }


class InventoryRepository:
    def __init__(self, pool):
        self.pool = pool

    @asynccontextmanager
    async def transaction(self, actor, household):
        async with user_transaction(self.pool, actor) as connection:
            # Membership is independently checked for every operation. Shared parent
            # locks prevent a revocation committing midway through a mutation.
            row = await (
                await connection.execute(
                    "SELECT public.lock_inventory_household(%s) AS allowed", (household,)
                )
            ).fetchone()
            if not row or not row["allowed"]:
                raise AppError(404, "not_found", "Household not found.")
            yield connection

    async def categories(self, actor, household):
        async with self.transaction(actor, household) as c:
            return await (
                await c.execute(
                    "SELECT id,household_id,name FROM public.inventory_categories "
                    "WHERE household_id IS NULL OR household_id=%s ORDER BY name",
                    (household,),
                )
            ).fetchall()

    async def create_category(self, actor, household, name):
        async with self.transaction(actor, household) as c:
            existing = await (
                await c.execute(
                    "SELECT id FROM public.inventory_categories WHERE "
                    "(household_id IS NULL OR household_id=%s) AND lower(btrim(name))=lower(%s)",
                    (household, name),
                )
            ).fetchone()
            if existing:
                raise AppError(409, "duplicate_category", "Category already exists.")
            return await (
                await c.execute(
                    "INSERT INTO public.inventory_categories(household_id,name) "
                    "VALUES(%s,%s) RETURNING id,household_id,name",
                    (household, name),
                )
            ).fetchone()

    async def item(self, c, household, item_id, lock=False, archived=False):
        query = SELECT + "WHERE i.household_id=%s AND i.id=%s "
        if not archived:
            query += "AND i.deleted_at IS NULL "
        if lock:
            query += "FOR UPDATE OF i"
        row = await (await c.execute(query, (household, item_id))).fetchone()
        if not row:
            raise AppError(404, "not_found", "Item not found.")
        return row

    async def detail(self, actor, household, item_id):
        async with self.transaction(actor, household) as c:
            row = await self.item(c, household, item_id, archived=True)
            names = await (
                await c.execute(
                    "SELECT public.inventory_actor_name(%s,%s) AS display_name",
                    (household, row["updated_by"]),
                )
            ).fetchone()
            row["updated_by_name"] = names["display_name"] if names else None
            return row

    async def list(self, actor, household, filters):
        archived = filters.get("archived", False)
        clauses, args = (
            [
                "i.household_id=%s",
                "i.deleted_at IS NOT NULL" if archived else "i.deleted_at IS NULL",
            ],
            [household],
        )
        for key, column in (
            ("category", "i.category_id"),
            ("type", "i.item_type"),
            ("condition", "i.condition"),
            ("location", "i.location"),
        ):
            if filters.get(key):
                clauses.append(column + "=%s")
                args.append(filters[key])
        if filters.get("search"):
            clauses.append("i.name ILIKE %s ESCAPE '\\'")
            term = filters["search"].replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            args.append("%" + term + "%")
        if filters.get("stock_status"):
            clauses.append(f"({STOCK})=%s")
            args.append(filters["stock_status"])
        where = "WHERE " + " AND ".join(clauses)
        async with self.transaction(actor, household) as c:
            # Parameterized filters and fixed sort expressions; no client SQL identifiers.
            rows = await (
                await c.execute(
                    SELECT + where + " ORDER BY " + SORTS[filters["sort"]] + " LIMIT %s OFFSET %s",
                    (*args, filters["page_size"], (filters["page"] - 1) * filters["page_size"]),
                )
            ).fetchall()
            total = (
                await (
                    await c.execute(
                        "SELECT count(*) AS n FROM public.inventory_items i " + where, args
                    )
                ).fetchone()
            )["n"]
            return {
                "items": rows,
                "total": total,
                "page": filters["page"],
                "page_size": filters["page_size"],
            }

    async def summary(self, actor, household):
        async with self.transaction(actor, household) as c:
            return await (
                await c.execute(
                    "SELECT count(*) AS total, "
                    "count(*) FILTER(WHERE stock_status='available') AS available, "
                    "count(*) FILTER(WHERE stock_status='low_stock') AS low_stock, "
                    "count(*) FILTER(WHERE stock_status='out_of_stock') AS out_of_stock, "
                    "count(*) FILTER(WHERE condition='working') AS working, "
                    "count(*) FILTER(WHERE condition='needs_repair') AS needs_repair, "
                    "count(*) FILTER(WHERE condition='broken') AS broken "
                    f"FROM (SELECT i.condition,{STOCK} AS stock_status "
                    "FROM public.inventory_items i "
                    "WHERE household_id=%s AND deleted_at IS NULL) s",
                    (household,),
                )
            ).fetchone()

    async def event(self, c, actor, household, item, action, before, after):
        old, new = snapshot(before or {}), snapshot(after)
        changes = {
            k: {"before": old.get(k), "after": v}
            for k, v in new.items()
            if k
            not in {
                "updated_at",
                "updated_by",
                "revision",
                "created_at",
                "created_by",
                "household_id",
                "id",
                "photo_path",
            }
            and old.get(k) != v
        }
        if action == "photo_changed":
            changes = {
                "photo": {
                    "before": bool(old.get("photo_path")),
                    "after": bool(new.get("photo_path")),
                }
            }
        await c.execute(
            "INSERT INTO public.inventory_activity"
            "(household_id,inventory_item_id,actor_user_id,action,changes) VALUES(%s,%s,%s,%s,%s)",
            (household, item, actor, action, Jsonb(changes)),
        )

    async def create(self, actor, household, fields):
        async with self.transaction(actor, household) as c:
            values = {**fields, "household_id": household, "created_by": actor, "updated_by": actor}
            query = sql.SQL(
                "INSERT INTO public.inventory_items ({}) VALUES ({}) RETURNING id"
            ).format(
                sql.SQL(",").join(map(sql.Identifier, values)),
                sql.SQL(",").join(sql.Placeholder() for _ in values),
            )
            item_id = (await (await c.execute(query, list(values.values()))).fetchone())["id"]
            row = await self.item(c, household, item_id)
            await self.event(c, actor, household, item_id, "created", None, row)
            return row

    async def write(self, c, actor, household, item_id, old, fields, action):
        fields = {**fields, "updated_by": actor}
        sets = sql.SQL(",").join(sql.SQL("{}=%s").format(sql.Identifier(k)) for k in fields)
        await c.execute(
            sql.SQL(
                "UPDATE public.inventory_items SET {},updated_at=clock_timestamp(),"
                "revision=revision+1 WHERE household_id=%s AND id=%s"
            ).format(sets),
            (*fields.values(), household, item_id),
        )
        row = await self.item(c, household, item_id, archived=True)
        await self.event(c, actor, household, item_id, action, old, row)
        return row

    async def activity(self, actor, household, item_id, page, size):
        async with self.transaction(actor, household) as c:
            await self.item(c, household, item_id, archived=True)
            rows = await (
                await c.execute(
                    "SELECT a.id,a.actor_user_id,a.action,a.changes,a.created_at, "
                    "public.inventory_actor_name(a.household_id,a.actor_user_id) AS actor_name "
                    "FROM public.inventory_activity a WHERE household_id=%s "
                    "AND inventory_item_id=%s ORDER BY created_at DESC,id LIMIT %s OFFSET %s",
                    (household, item_id, size, (page - 1) * size),
                )
            ).fetchall()
            return {"items": rows, "page": page, "page_size": size}
