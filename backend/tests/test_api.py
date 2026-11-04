from datetime import UTC, datetime

import pytest

from app.core.exceptions import AppError
from app.dependencies.auth import get_current_user
from app.models.auth import AuthenticatedUser
from app.schemas.household import Household
from tests.conftest import HOUSEHOLD_ID, USER_ID


def household():
    return Household(
        id=HOUSEHOLD_ID,
        name="Home",
        description=None,
        image_path=None,
        created_by=USER_ID,
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
        role="admin",
    )


def test_profile_update_trims_name_and_rejects_identity_fields(client, service):
    service.update_profile.return_value = {
        "id": str(USER_ID),
        "email": "person@example.test",
        "display_name": "Person",
        "avatar_path": None,
        "households": [],
    }
    headers = {"Authorization": "Bearer valid-token"}
    response = client.patch("/api/v1/me", json={"display_name": " Person "}, headers=headers)
    assert response.status_code == 200
    assert service.update_profile.call_args.args[1].display_name == "Person"
    for payload in ({"display_name": " "}, {"display_name": "Person", "id": str(USER_ID)}):
        assert client.patch("/api/v1/me", json=payload, headers=headers).status_code == 422


def test_member_listing_pagination_is_bounded(client, service):
    service.members.return_value = []
    headers = {"Authorization": "Bearer valid-token"}
    path = f"/api/v1/households/{HOUSEHOLD_ID}/members"
    assert client.get(path, headers=headers).status_code == 200
    assert client.get(path + "?limit=101", headers=headers).status_code == 422
    assert client.get(path + "?offset=-1", headers=headers).status_code == 422


@pytest.mark.parametrize("path", ["/health", "/api/v1/health"])
def test_health(client, path):
    response = client.get(path)
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


@pytest.mark.parametrize("header", [None, "Bearer invalid", "Basic not-bearer", "Bearer"])
def test_protected_requires_verified_token(client, header, service):
    response = client.get("/api/v1/me", headers={"Authorization": header} if header else {})
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthorized"
    assert response.headers["www-authenticate"] == "Bearer"
    service.me.assert_not_called()


def test_verified_identity_reaches_service(client, service):
    service.me.return_value = {
        "id": str(USER_ID),
        "email": "person@example.test",
        "display_name": "Person",
        "households": [],
    }
    response = client.get("/api/v1/me", headers={"Authorization": "Bearer valid-token"})
    assert response.status_code == 200
    assert response.json()["id"] == str(USER_ID)
    assert service.me.call_args.args[0].id == USER_ID


def test_user_dependency_override(client, service):
    client.app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(USER_ID)
    service.list_households.return_value = [household()]
    response = client.get("/api/v1/households")
    assert response.status_code == 200
    assert response.json()[0]["role"] == "admin"


def test_household_creation_and_input_validation(client, service):
    service.create_household.return_value = household()
    response = client.post(
        "/api/v1/households",
        json={"name": " Home "},
        headers={"Authorization": "Bearer valid-token"},
    )
    assert response.status_code == 201
    assert service.create_household.call_args.args[1].name == "Home"
    for payload in [
        {"name": " "},
        {"name": "Home", "role": "admin"},
        {"name": "Home", "created_by": str(USER_ID)},
    ]:
        response = client.post(
            "/api/v1/households", json=payload, headers={"Authorization": "Bearer valid-token"}
        )
        assert response.status_code == 422
        assert set(response.json()) == {"error"}


def test_cross_household_failure_is_not_found(client, service):
    service.get_household.side_effect = AppError(404, "not_found", "Household not found.")
    response = client.get(
        f"/api/v1/households/{HOUSEHOLD_ID}", headers={"Authorization": "Bearer valid-token"}
    )
    assert response.status_code == 404


def test_internal_errors_do_not_expose_secrets(client, service):
    service.me.side_effect = RuntimeError("postgresql://private:password@server/database")
    response = client.get("/api/v1/me", headers={"Authorization": "Bearer valid-token"})
    assert response.status_code == 500
    assert "password" not in response.text
    assert response.json() == {
        "error": {"code": "internal_error", "message": "An unexpected error occurred."}
    }
