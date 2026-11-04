"""Validate the separate hosted test target before any integration-test writes."""

import re
from urllib.parse import urlsplit

from psycopg import ProgrammingError
from psycopg.conninfo import conninfo_to_dict


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
