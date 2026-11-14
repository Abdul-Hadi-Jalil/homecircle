from functools import lru_cache
from typing import Literal
from urllib.parse import urlsplit

from psycopg import ProgrammingError
from psycopg.conninfo import conninfo_to_dict
from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", extra="ignore", env_ignore_empty=True, hide_input_in_errors=True
    )

    app_env: Literal["development", "test", "production"] = "development"
    app_name: str = "HomeCircle API"
    database_url: SecretStr
    database_sslmode: Literal["verify-full", "disable"] = "verify-full"
    database_sslrootcert: str | None = None
    database_pool_min: int = Field(default=1, ge=1)
    database_pool_max: int = Field(default=5, ge=1)
    database_pool_timeout: float = Field(default=10, gt=0)
    database_connect_timeout: int = Field(default=10, ge=1)
    supabase_url: str
    supabase_publishable_key: SecretStr | None = None
    supabase_jwt_issuer: str | None = None
    supabase_jwt_audience: str = "authenticated"
    supabase_jwt_mode: Literal["jwks", "legacy_hs256"] = "jwks"
    supabase_jwt_secret: SecretStr | None = None
    cors_allowed_origins: list[str] = []
    invitation_pepper: SecretStr | None = None
    invitation_expiry_days: int = Field(default=7, ge=1, le=30)
    invitation_max_uses: int = Field(default=10, ge=1, le=1000)
    chat_image_max_bytes: int = Field(default=5 * 1024 * 1024, ge=1024, le=5 * 1024 * 1024)
    chat_message_rate: int = Field(default=60, ge=1, le=600)
    chat_reaction_rate: int = Field(default=120, ge=1, le=1000)
    chat_upload_rate: int = Field(default=10, ge=1, le=60)

    @model_validator(mode="after")
    def validate_configuration(self):
        if self.invitation_pepper and len(self.invitation_pepper.get_secret_value()) < 32:
            raise ValueError("INVITATION_PEPPER must contain at least 32 characters")
        if not self.database_url.get_secret_value().strip():
            raise ValueError("DATABASE_URL is required")
        try:
            connection = conninfo_to_dict(self.database_url.get_secret_value())
        except ProgrammingError:
            raise ValueError("DATABASE_URL must be a valid PostgreSQL connection string") from None
        if connection.get("port") == "6543":
            raise ValueError("Use the direct connection or session pooler on port 5432")
        if self.database_pool_max < self.database_pool_min:
            raise ValueError("DATABASE_POOL_MAX must be at least DATABASE_POOL_MIN")
        self.supabase_url = self.supabase_url.rstrip("/")
        origin = urlsplit(self.supabase_url)
        if not origin.hostname or origin.username or origin.password or origin.path:
            raise ValueError(
                "SUPABASE_URL must be the project origin without a path or credentials"
            )
        if origin.scheme != "https" and not (
            self.app_env in ("development", "test")
            and origin.scheme == "http"
            and origin.hostname in ("localhost", "127.0.0.1", "::1")
        ):
            raise ValueError("SUPABASE_URL must use HTTPS outside local development")
        if origin.query or origin.fragment:
            raise ValueError("SUPABASE_URL cannot include a query or fragment")
        if self.app_env == "production" and self.database_sslmode != "verify-full":
            raise ValueError("Production database connections require verify-full TLS")
        if self.database_sslmode == "disable" and connection.get("host") not in (
            "localhost",
            "127.0.0.1",
            "::1",
        ):
            raise ValueError("TLS may be disabled only for a local development database")
        if self.database_sslmode == "disable" and connection.get("hostaddr", "127.0.0.1") not in (
            "127.0.0.1",
            "::1",
        ):
            raise ValueError("TLS may be disabled only for a local development database")
        if self.supabase_jwt_mode == "legacy_hs256":
            if (
                not self.supabase_jwt_secret
                or len(self.supabase_jwt_secret.get_secret_value()) < 32
            ):
                raise ValueError(
                    "Legacy JWT mode requires a server-only secret of at least 32 bytes"
                )
        self.supabase_jwt_issuer = self.supabase_jwt_issuer or f"{self.supabase_url}/auth/v1"
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
