from unittest.mock import AsyncMock
from uuid import UUID

import pytest
from fastapi.testclient import TestClient

from app.core.config import Settings
from app.core.exceptions import AppError
from app.dependencies.auth import get_token_verifier
from app.dependencies.services import get_household_service
from app.main import create_app
from app.models.auth import AuthenticatedUser

USER_ID = UUID("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
OTHER_ID = UUID("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
HOUSEHOLD_ID = UUID("11111111-1111-4111-8111-111111111111")


@pytest.fixture
def settings():
    return Settings(
        _env_file=None,
        app_env="test",
        # Placeholder only: unit tests replace the pool and never connect.
        database_url="postgresql://homecircle_api:test@db.example.test:5432/postgres",
        supabase_url="https://test.supabase.co",
    )


class FakeVerifier:
    async def verify(self, token):
        if token != "valid-token":
            raise AppError(401, "unauthorized", "A valid access token is required.")
        return AuthenticatedUser(USER_ID, "person@example.test")


@pytest.fixture
def service():
    return AsyncMock()


@pytest.fixture
def client(settings, service):
    app = create_app(settings)
    app.dependency_overrides[get_token_verifier] = lambda: FakeVerifier()
    app.dependency_overrides[get_household_service] = lambda: service
    # These API unit tests override external dependencies, without opening a database.
    api_client = TestClient(app, raise_server_exceptions=False)
    yield api_client
    api_client.close()
