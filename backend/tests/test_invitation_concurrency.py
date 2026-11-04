"""Committed concurrency checks, exclusively on the guarded hosted test project.

Only generated fixture IDs are deleted. No database/schema reset is used.
"""

import os
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

import psycopg
import pytest
from psycopg.rows import dict_row

from tests.test_database_integration import as_actor, create, issue_invite, user
from tests.test_database_integration import database as database  # noqa: F401

pytestmark = pytest.mark.integration


@pytest.mark.parametrize("same_actor", [False, True])
def test_concurrent_redemption_has_one_consumption(database, same_actor):
    # Requesting database invokes the target guard before any committed writes.
    tls = {"sslmode": "verify-full", "connect_timeout": 10}
    if cert := os.getenv("SUPABASE_TEST_DATABASE_SSLROOTCERT"):
        tls["sslrootcert"] = cert

    def connect():
        return psycopg.connect(
            os.environ["SUPABASE_TEST_DATABASE_URL"], row_factory=dict_row, **tls
        )

    home, actors = None, []
    digest = os.urandom(32).hex()
    try:
        with connect() as seed:
            actors = [user(seed) for _ in range(3)]
            home = create(seed, actors[0])
            invite = issue_invite(seed, actors[0], home, digest)

        barrier = Barrier(2, timeout=20)

        def redeem(actor):
            with connect() as connection:
                as_actor(connection, actor, "homecircle_api")
                barrier.wait()
                return connection.execute(
                    "SELECT public.resolve_household_invite(%s,true) AS result", (digest,)
                ).fetchone()["result"]

        targets = [actors[1], actors[1] if same_actor else actors[2]]
        with ThreadPoolExecutor(max_workers=2) as workers:
            results = list(workers.map(redeem, targets))
        assert sorted(r["status"] for r in results) == (
            ["ok", "ok"] if same_actor else ["invitation_limit", "ok"]
        )
        with connect() as check:
            assert (
                check.execute(
                    "SELECT uses_count FROM public.household_invites WHERE id=%s", (invite,)
                ).fetchone()["uses_count"]
                == 1
            )
            rows = check.execute(
                "SELECT role FROM public.household_members WHERE household_id=%s", (home,)
            ).fetchall()
            assert sorted(r["role"] for r in rows) == ["admin", "member"]
    finally:
        with connect() as cleanup:
            if home:
                cleanup.execute("DELETE FROM public.households WHERE id=%s", (home,))
            for actor in actors:
                cleanup.execute("DELETE FROM auth.users WHERE id=%s", (actor,))
