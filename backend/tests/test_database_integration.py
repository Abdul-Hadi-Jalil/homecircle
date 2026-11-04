"""Run only against an explicitly opted-in separate hosted Supabase test project.

Every test rolls back its transaction. Migrations must already be applied by the CLI.
No schema reset or drop is performed. App-project connections are rejected.
"""

import os
from uuid import uuid4

import psycopg
import pytest
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from tests.database_target import validate_hosted_test_target

pytestmark = pytest.mark.integration


@pytest.fixture
def database():
    url = os.getenv("SUPABASE_TEST_DATABASE_URL")
    if not url or os.getenv("HOMECIRCLE_TEST_DB") != "hosted-test":
        pytest.skip("A separate hosted Supabase test project is not configured")
    try:
        validate_hosted_test_target(
            url,
            os.getenv("HOMECIRCLE_TEST_PROJECT_REF", ""),
            os.getenv("SUPABASE_URL", ""),
            os.getenv("APP_ENV", "development"),
        )
    except ValueError as error:
        pytest.fail(str(error), pytrace=False)
    tls = {"sslmode": "verify-full", "connect_timeout": 10}
    if root_cert := os.getenv("SUPABASE_TEST_DATABASE_SSLROOTCERT"):
        tls["sslrootcert"] = root_cert
    with psycopg.connect(url, row_factory=dict_row, **tls) as connection:
        with connection.transaction(force_rollback=True):
            yield connection


def as_actor(connection, user_id, role="authenticated"):
    # Roles are fixed test constants, never externally supplied SQL identifiers.
    connection.execute("RESET ROLE")
    connection.execute(
        "SELECT set_config('request.jwt.claims', %s::text, true), "
        "set_config('request.jwt.claim.sub', %s, true)",
        (Jsonb({"sub": str(user_id), "role": "authenticated"}), str(user_id)),
    )
    if role == "homecircle_api":
        connection.execute("SET LOCAL ROLE homecircle_api")
    else:
        connection.execute("SET LOCAL ROLE authenticated")


def user(connection):
    connection.execute("RESET ROLE")
    user_id = uuid4()
    connection.execute(
        "INSERT INTO auth.users (id, email) VALUES (%s, %s)", (user_id, f"{user_id}@example.test")
    )
    return user_id


def create(connection, actor):
    as_actor(connection, actor)
    return connection.execute(
        "SELECT * FROM public.create_household(%s, %s)", ("Integration home", None)
    ).fetchone()["id"]


def test_signup_profile_and_atomic_creator_admin(database):
    actor = user(database)
    household_id = create(database, actor)
    membership = database.execute(
        "SELECT role FROM public.household_members WHERE household_id = %s AND user_id = %s",
        (household_id, actor),
    ).fetchone()
    assert membership["role"] == "admin"
    assert database.execute("SELECT id FROM public.profiles").fetchone()["id"] == actor


def test_multi_household_and_cross_household_rls(database):
    actor, outsider = user(database), user(database)
    own = {create(database, actor), create(database, actor)}
    other_household = create(database, outsider)
    for role in ("authenticated", "homecircle_api"):
        as_actor(database, actor, role)
        rows = database.execute("SELECT id FROM public.households").fetchall()
        assert {row["id"] for row in rows} == own
        assert (
            database.execute(
                "SELECT * FROM public.households WHERE id = %s", (other_household,)
            ).fetchone()
            is None
        )


def test_member_cannot_self_promote_or_delete_household(database):
    admin, member = user(database), user(database)
    household_id = create(database, admin)
    database.execute("RESET ROLE")
    database.execute(
        "INSERT INTO public.household_members (household_id, user_id, role) "
        "VALUES (%s, %s, 'member')",
        (household_id, member),
    )
    as_actor(database, member)
    with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
        database.execute(
            "UPDATE public.household_members SET role = 'admin' WHERE user_id = %s", (member,)
        )
    with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
        database.execute("SELECT public.set_member_role(%s, %s, 'admin')", (household_id, member))
    assert (
        database.execute(
            "DELETE FROM public.households WHERE id = %s RETURNING id", (household_id,)
        ).fetchone()
        is None
    )


def test_last_admin_cannot_be_removed_or_demoted(database):
    actor = user(database)
    household_id = create(database, actor)
    with pytest.raises(psycopg.errors.CheckViolation), database.transaction():
        database.execute("SELECT public.set_member_role(%s, %s, 'member')", (household_id, actor))
    with pytest.raises(psycopg.errors.CheckViolation), database.transaction():
        database.execute("SELECT public.remove_household_member(%s, %s)", (household_id, actor))


def test_creation_failure_leaves_no_orphan_household(database):
    actor = user(database)
    database.execute("RESET ROLE")
    # Inject a failure at the second write, after household insertion has succeeded.
    # The outer fixture rolls this temporary test trigger back with all test data.
    database.execute(
        "CREATE FUNCTION pg_temp.reject_test_membership() RETURNS trigger "
        "LANGUAGE plpgsql AS $$ BEGIN RAISE check_violation "
        "USING MESSAGE = 'Injected membership failure'; END $$"
    )
    database.execute(
        "CREATE TRIGGER homecircle_test_reject_membership "
        "BEFORE INSERT ON public.household_members FOR EACH ROW "
        "EXECUTE FUNCTION pg_temp.reject_test_membership()"
    )
    before = database.execute("SELECT count(*) AS count FROM public.households").fetchone()["count"]
    as_actor(database, actor)
    with pytest.raises(psycopg.errors.CheckViolation), database.transaction():
        database.execute("SELECT * FROM public.create_household('Must roll back', null)")
    database.execute("RESET ROLE")
    after = database.execute("SELECT count(*) AS count FROM public.households").fetchone()["count"]
    assert after == before


def test_direct_household_insert_and_profile_identity_changes_are_denied(database):
    actor = user(database)
    as_actor(database, actor)
    with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
        database.execute(
            "INSERT INTO public.households (name, created_by) VALUES ('Unsafe', %s)", (actor,)
        )
    with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
        database.execute("UPDATE public.profiles SET id = %s WHERE id = %s", (uuid4(), actor))


def test_last_admin_account_deletion_is_blocked(database):
    actor = user(database)
    create(database, actor)
    database.execute("RESET ROLE")
    with pytest.raises(psycopg.errors.CheckViolation), database.transaction():
        database.execute("DELETE FROM auth.users WHERE id = %s", (actor,))


def test_reserved_storage_is_private_and_uploads_denied(database):
    actor = user(database)
    household_id = create(database, actor)
    database.execute("RESET ROLE")
    buckets = database.execute(
        "SELECT public FROM storage.buckets WHERE id IN "
        "('household-images', 'inventory-photos', "
        "'repair-attachments', 'chat-attachments')"
    ).fetchall()
    assert len(buckets) == 4
    assert all(not row["public"] for row in buckets)
    as_actor(database, actor)
    with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
        database.execute(
            "INSERT INTO storage.objects (bucket_id, name) VALUES (%s, %s)",
            ("household-images", f"{household_id}/{actor}/test.jpg"),
        )


def issue_invite(connection, admin, household_id, digest="a" * 64, uses=1):
    as_actor(connection, admin, "homecircle_api")
    return connection.execute(
        "SELECT public.issue_household_invite(%s, %s, "
        "clock_timestamp() + interval '7 days', %s) AS id",
        (household_id, digest, uses),
    ).fetchone()["id"]


def resolve_invite(connection, actor, digest="a" * 64, redeem=True):
    as_actor(connection, actor, "homecircle_api")
    return connection.execute(
        "SELECT public.resolve_household_invite(%s, %s) AS result", (digest, redeem)
    ).fetchone()["result"]


def test_invite_idempotency_member_role_and_limit(database):
    admin, member, other = user(database), user(database), user(database)
    home = create(database, admin)
    issue_invite(database, admin, home)
    result = resolve_invite(database, member)
    assert result["status"] == "ok" and result["role"] == "member"
    assert result["already_member"] is False
    assert resolve_invite(database, member)["already_member"] is True
    assert resolve_invite(database, other)["status"] == "invitation_limit"
    as_actor(database, admin, "homecircle_api")
    assert (
        database.execute(
            "SELECT uses_count FROM public.household_invites WHERE household_id=%s", (home,)
        ).fetchone()["uses_count"]
        == 1
    )


def test_invite_rotation_revocation_expiry_and_hash_secrecy(database):
    admin, outsider = user(database), user(database)
    home = create(database, admin)
    issue_invite(database, admin, home)
    second = issue_invite(database, admin, home, "b" * 64)
    assert resolve_invite(database, outsider)["status"] == "revoked_invitation"
    as_actor(database, admin, "homecircle_api")
    database.execute("SELECT public.revoke_household_invite(%s,%s)", (home, second))
    assert resolve_invite(database, outsider, "b" * 64)["status"] == "revoked_invitation"
    third = issue_invite(database, admin, home, "c" * 64)
    database.execute("RESET ROLE")
    database.execute(
        "UPDATE public.household_invites SET created_at=now()-interval '2 days', "
        "expires_at=now()-interval '1 day' WHERE id=%s",
        (third,),
    )
    assert resolve_invite(database, outsider, "c" * 64)["status"] == "expired_invitation"
    as_actor(database, admin, "homecircle_api")
    with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
        database.execute("SELECT code_hash FROM public.household_invites")
    as_actor(database, outsider, "homecircle_api")
    assert database.execute("SELECT id FROM public.household_invites").fetchall() == []
    with pytest.raises(psycopg.errors.InsufficientPrivilege), database.transaction():
        database.execute(
            "SELECT public.issue_household_invite(%s,%s,now()+interval '1 day',1)", (home, "d" * 64)
        )


def test_rate_counter_persists_across_transactions(database):
    actor = user(database)
    as_actor(database, actor, "homecircle_api")
    for _ in range(20):
        assert database.execute("SELECT public.consume_invite_attempt() AS ok").fetchone()["ok"]
    assert not database.execute("SELECT public.consume_invite_attempt() AS ok").fetchone()["ok"]
