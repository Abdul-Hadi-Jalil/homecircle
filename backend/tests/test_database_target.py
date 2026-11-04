import pytest

from tests.database_target import validate_hosted_test_target

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
