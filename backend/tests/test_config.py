import pytest
from pydantic import ValidationError

from app.core.config import Settings


def test_missing_configuration_fails_clearly(monkeypatch):
    for key in ["DATABASE_URL", "SUPABASE_URL"]:
        monkeypatch.delenv(key, raising=False)
    with pytest.raises(ValidationError) as error:
        Settings(_env_file=None)
    assert "database_url" in str(error.value)
    assert "supabase_url" in str(error.value)


@pytest.mark.parametrize(
    "overrides",
    [
        {"database_url": "postgresql://homecircle_api:example@host:6543/postgres"},
        {"app_env": "production", "database_sslmode": "disable"},
        {"supabase_jwt_mode": "legacy_hs256"},
        {"database_pool_min": 6, "database_pool_max": 2},
        {"database_sslmode": "require"},
        {"supabase_url": "https://"},
        {"supabase_url": "http://remote.example.test"},
    ],
)
def test_unsafe_settings_rejected(settings, overrides):
    with pytest.raises(ValidationError):
        Settings(_env_file=None, **{**settings.model_dump(), **overrides})
