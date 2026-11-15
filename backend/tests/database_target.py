"""Validate disposable local/hosted targets before any integration-test writes."""

import os
import re
from urllib.parse import urlsplit

from psycopg import ProgrammingError
from psycopg.conninfo import conninfo_to_dict

LOCAL_TEST_PORT = "55422"
LOCAL_TEST_MARKER = "homecircle-local-integration-v1"


def validate_hosted_test_target(url: str, test_ref: str, app_url: str, app_env: str) -> None:
    if app_env == "production":
        raise ValueError("Integration tests cannot run with APP_ENV=production")
    if not re.fullmatch(r"[a-z0-9]{20}", test_ref):
        raise ValueError("Set HOMECIRCLE_TEST_PROJECT_REF to the separate hosted test project ref")
    app = urlsplit(app_url)
    if (
        app.scheme != "https"
        or not app.hostname
        or not re.fullmatch(r"[a-z0-9]{20}\.supabase\.co", app.hostname)
    ):
        raise ValueError("Set SUPABASE_URL to the app project's standard hosted HTTPS URL")
    if app.hostname == f"{test_ref}.supabase.co":
        raise ValueError("The integration test project must differ from the app project")
    try:
        connection = conninfo_to_dict(url)
    except ProgrammingError:
        raise ValueError("SUPABASE_TEST_DATABASE_URL is not a valid connection string") from None
    host = connection.get("host", "")
    user = connection.get("user", "")
    direct = host == f"db.{test_ref}.supabase.co"
    pooler = host.endswith(".pooler.supabase.com") and user.endswith(f".{test_ref}")
    if not (direct or pooler) or connection.get("hostaddr"):
        raise ValueError("The database connection must target the declared hosted test project")
    if connection.get("port", "5432") != "5432":
        raise ValueError("Use a direct or session-pooler test connection on port 5432")
    if connection.get("sslmode", "verify-full") != "verify-full":
        raise ValueError("Hosted integration tests require verified TLS")


def validate_local_test_target(url: str, app_env: str) -> None:
    if app_env == "production":
        raise ValueError("Integration tests cannot run with APP_ENV=production")
    try:
        connection = conninfo_to_dict(url)
    except ProgrammingError:
        raise ValueError("SUPABASE_TEST_DATABASE_URL is not a valid connection string") from None
    if (
        connection.get("host") != "127.0.0.1"
        or connection.get("port") != LOCAL_TEST_PORT
        or connection.get("dbname") != "postgres"
        or connection.get("user") != "postgres"
        or any(key in connection for key in ("hostaddr", "service", "servicefile", "options"))
        or connection.get("sslmode", "disable") != "disable"
    ):
        raise ValueError("Local tests require the dedicated 127.0.0.1:55422/postgres instance")


def integration_connection_options() -> dict:
    url = os.environ.get("SUPABASE_TEST_DATABASE_URL", "")
    mode = os.environ.get("HOMECIRCLE_TEST_DB", "")
    app_env = os.environ.get("APP_ENV", "development")
    if mode == "local-test":
        validate_local_test_target(url, app_env)
        # Pin the actual socket address too, overriding inherited PGHOSTADDR.
        return {"sslmode": "disable", "hostaddr": "127.0.0.1", "connect_timeout": 10}
    if mode != "hosted-test":
        raise ValueError("Select local-test or hosted-test explicitly")
    validate_hosted_test_target(
        url,
        os.environ.get("HOMECIRCLE_TEST_PROJECT_REF", ""),
        os.environ.get("SUPABASE_URL", ""),
        app_env,
    )
    options = {"sslmode": "verify-full", "connect_timeout": 10}
    if cert := os.environ.get("SUPABASE_TEST_DATABASE_SSLROOTCERT"):
        options["sslrootcert"] = cert
    return options


def verify_local_test_database(connection) -> None:
    if os.environ.get("HOMECIRCLE_TEST_DB") != "local-test":
        return
    row = connection.execute(
        "SELECT current_setting('homecircle.test_instance', true) AS marker"
    ).fetchone()
    if row["marker"] != LOCAL_TEST_MARKER:
        raise ValueError("Local database lacks the disposable HomeCircle test marker")
