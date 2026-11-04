import asyncio
from contextlib import asynccontextmanager
from unittest.mock import AsyncMock

import pytest
import uvicorn
from fastapi.testclient import TestClient

from app.db.pool import create_pool, user_transaction, verify_database_role
from app.main import create_app
from app.repositories.households import HouseholdRepository
from tests.conftest import USER_ID


def test_uvicorn_uses_psycopg_compatible_event_loop():
    config = uvicorn.Config(
        "app.main:create_app", factory=True, loop="app.core.event_loop:create_event_loop"
    )
    loop = config.get_loop_factory()()
    try:
        assert isinstance(loop, asyncio.SelectorEventLoop)
    finally:
        loop.close()


class FakeConnection:
    def __init__(self, role="homecircle_api", bypass=False):
        self.role = role
        self.bypass = bypass
        self.execute = AsyncMock(side_effect=self.query)
        self.committed = False
        self.rolled_back = False

    async def query(self, query, params=None):
        return self

    async def fetchone(self):
        return {"name": self.role, "rolsuper": False, "rolbypassrls": self.bypass}

    @asynccontextmanager
    async def transaction(self):
        try:
            yield self
            self.committed = True
        except Exception:
            self.rolled_back = True
            raise


class FakePool:
    def __init__(self, connection=None):
        self.conn = connection or FakeConnection()
        self.open = AsyncMock()
        self.close = AsyncMock()

    @asynccontextmanager
    async def connection(self):
        yield self.conn


def test_lifespan_opens_and_closes_pool(settings):
    pool = FakePool()
    with TestClient(create_app(settings, pool_factory=lambda settings: pool)) as client:
        assert client.get("/health").json() == {"status": "ok"}
        pool.open.assert_awaited_once()
        pool.close.assert_not_called()
    pool.close.assert_awaited_once()


def test_failed_startup_also_closes_pool(settings):
    pool = FakePool(FakeConnection(role="postgres"))
    with (
        pytest.raises(RuntimeError),
        TestClient(create_app(settings, pool_factory=lambda settings: pool)),
    ):
        pass
    pool.close.assert_awaited_once()


@pytest.mark.parametrize("role,bypass", [("postgres", False), ("homecircle_api", True)])
async def test_privileged_database_role_rejected(role, bypass):
    with pytest.raises(RuntimeError):
        await verify_database_role(FakePool(FakeConnection(role, bypass)))


async def test_user_context_is_transaction_local_and_rolls_back():
    pool = FakePool()
    with pytest.raises(RuntimeError):
        async with user_transaction(pool, USER_ID):
            raise RuntimeError("write failed")
    assert pool.conn.rolled_back
    query, params = pool.conn.execute.call_args.args
    assert "set_config('request.jwt.claims', %s::text, true)" in query
    assert params[0].obj["sub"] == str(USER_ID)


async def test_household_rpc_failure_rolls_back_whole_transaction():
    pool = FakePool()
    calls = 0

    async def execute(query, params):
        nonlocal calls
        calls += 1
        if calls == 2:
            assert query == "SELECT * FROM public.create_household(%s, %s)"
            raise RuntimeError("membership insertion failed")

    pool.conn.execute.side_effect = execute
    with pytest.raises(RuntimeError):
        await HouseholdRepository(pool).create(USER_ID, "Home", None)
    assert pool.conn.rolled_back
    assert not pool.conn.committed


def test_pool_is_lazy_and_disables_prepared_statements(settings):
    pool = create_pool(settings)
    assert pool.closed
    assert pool.kwargs["prepare_threshold"] is None
    assert pool.kwargs["sslmode"] == "verify-full"
