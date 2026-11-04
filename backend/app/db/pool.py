from contextlib import asynccontextmanager
from uuid import UUID

from psycopg.rows import dict_row
from psycopg.types.json import Jsonb
from psycopg_pool import AsyncConnectionPool

from app.core.config import Settings


def create_pool(settings: Settings) -> AsyncConnectionPool:
    kwargs = {
        "row_factory": dict_row,
        "autocommit": False,
        "prepare_threshold": None,
        "sslmode": settings.database_sslmode,
        "connect_timeout": settings.database_connect_timeout,
        "application_name": "homecircle-api",
    }
    if settings.database_sslrootcert:
        kwargs["sslrootcert"] = settings.database_sslrootcert
    return AsyncConnectionPool(
        settings.database_url.get_secret_value(),
        kwargs=kwargs,
        open=False,
        min_size=settings.database_pool_min,
        max_size=settings.database_pool_max,
        timeout=settings.database_pool_timeout,
        reconnect_timeout=settings.database_connect_timeout,
        check=AsyncConnectionPool.check_connection,
    )


async def verify_database_role(pool):
    async with pool.connection() as connection:
        cursor = await connection.execute(
            "SELECT current_user AS name, rolsuper, rolbypassrls "
            "FROM pg_roles WHERE rolname = current_user"
        )
        role = await cursor.fetchone()
        if not role or role["name"] != "homecircle_api" or role["rolsuper"] or role["rolbypassrls"]:
            raise RuntimeError("DATABASE_URL must use the restricted homecircle_api role")


@asynccontextmanager
async def user_transaction(pool, user_id: UUID):
    async with pool.connection() as connection, connection.transaction():
        # SET LOCAL identity disappears on commit/rollback before the connection is reused.
        await connection.execute(
            "SELECT set_config('request.jwt.claims', %s::text, true), "
            "set_config('request.jwt.claim.sub', %s, true)",
            (Jsonb({"sub": str(user_id), "role": "authenticated"}), str(user_id)),
        )
        yield connection
