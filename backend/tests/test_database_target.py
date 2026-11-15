from unittest.mock import Mock

import pytest

from tests.database_target import (
    LOCAL_TEST_MARKER,
    integration_connection_options,
    validate_hosted_test_target,
    validate_local_test_target,
    verify_local_test_database,
)

TEST_REF = "t" * 20
APP_URL = f"https://{'a' * 20}.supabase.co"
DIRECT = f"postgresql://postgres:example@db.{TEST_REF}.supabase.co:5432/postgres"


@pytest.mark.parametrize(
    "url",
    [
        DIRECT,
        f"postgresql://postgres.{TEST_REF}:example@aws-0-example.pooler.supabase.com:5432/postgres",
    ],
)
def test_allows_declared_separate_hosted_project(url):
    validate_hosted_test_target(url, TEST_REF, APP_URL, "test")


@pytest.mark.parametrize(
    "url,ref,app_url,app_env",
    [
        (DIRECT, TEST_REF, APP_URL, "production"),
        (DIRECT, "", APP_URL, "test"),
        (DIRECT, TEST_REF, "", "test"),
        (DIRECT, TEST_REF, f"https://{TEST_REF}.supabase.co", "test"),
        (DIRECT.replace(TEST_REF, "x" * 20), TEST_REF, APP_URL, "test"),
        (DIRECT.replace("5432", "6543"), TEST_REF, APP_URL, "test"),
        (DIRECT + "?sslmode=disable", TEST_REF, APP_URL, "test"),
        ("postgresql://postgres:example@127.0.0.1:5432/postgres", TEST_REF, APP_URL, "test"),
        (DIRECT + "?hostaddr=127.0.0.1", TEST_REF, APP_URL, "test"),
    ],
)
def test_refuses_wrong_or_unsafe_target(url, ref, app_url, app_env):
    with pytest.raises(ValueError):
        validate_hosted_test_target(url, ref, app_url, app_env)


LOCAL_URL = "postgresql://postgres:postgres@127.0.0.1:55422/postgres"


@pytest.mark.parametrize(
    "url",
    [
        DIRECT,
        LOCAL_URL.replace("55422", "5432"),
        LOCAL_URL.replace("55422", "54322"),
        LOCAL_URL.replace("127.0.0.1", "localhost"),
        LOCAL_URL.replace("/postgres", "/homecircle"),
        LOCAL_URL + "?hostaddr=10.0.0.1",
        LOCAL_URL + "?service=production",
        LOCAL_URL + "?options=-c%20role=postgres",
        LOCAL_URL + "?sslmode=require",
    ],
)
def test_local_guard_rejects_remote_ambiguous_or_wrong_database(url):
    with pytest.raises(ValueError):
        validate_local_test_target(url, "test")


def test_local_guard_requires_opt_in_and_pins_socket_address(monkeypatch):
    monkeypatch.setenv("SUPABASE_TEST_DATABASE_URL", LOCAL_URL)
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.delenv("HOMECIRCLE_TEST_DB", raising=False)
    with pytest.raises(ValueError):
        integration_connection_options()
    monkeypatch.setenv("HOMECIRCLE_TEST_DB", "local-test")
    monkeypatch.setenv("PGHOSTADDR", "203.0.113.1")
    assert integration_connection_options()["hostaddr"] == "127.0.0.1"
    assert integration_connection_options()["sslmode"] == "disable"
    monkeypatch.setenv("APP_ENV", "production")
    with pytest.raises(ValueError):
        integration_connection_options()


def test_local_database_must_have_disposable_instance_marker(monkeypatch):
    monkeypatch.setenv("HOMECIRCLE_TEST_DB", "local-test")
    connection = Mock()
    connection.execute.return_value.fetchone.return_value = {"marker": None}
    with pytest.raises(ValueError, match="disposable HomeCircle test marker"):
        verify_local_test_database(connection)
    connection.execute.return_value.fetchone.return_value = {"marker": LOCAL_TEST_MARKER}
    verify_local_test_database(connection)
