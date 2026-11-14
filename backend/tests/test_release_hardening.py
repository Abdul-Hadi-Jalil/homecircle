import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from tests.test_pool import FakePool


def test_every_feature_route_requires_verified_identity(settings):
    import re

    from app.dependencies.auth import get_token_verifier
    from tests.conftest import FakeVerifier

    app = create_app(settings)
    app.dependency_overrides[get_token_verifier] = lambda: FakeVerifier()
    routes = app.openapi()["paths"]
    checked = 0
    client = TestClient(app, raise_server_exceptions=False)
    try:
        for path, operations in routes.items():
            if not path.startswith("/api/v1/") or path == "/api/v1/health":
                continue
            target = re.sub(r"\{[^}]+\}", "11111111-1111-4111-8111-111111111111", path)
            for method, operation in operations.items():
                if method not in {"get", "post", "put", "patch", "delete"}:
                    continue
                assert operation.get("security"), (method, path)
                response = client.request(method, target, json={})
                assert response.status_code == 401, (method, path, response.text)
                checked += 1
        assert checked > 70
    finally:
        client.close()


def test_production_disables_schema_and_docs(settings):
    settings.app_env = "production"
    client = TestClient(create_app(settings))
    try:
        for path in ("/docs", "/redoc", "/openapi.json"):
            assert client.get(path).status_code == 404
        assert client.get("/health").status_code == 200
    finally:
        client.close()


@pytest.mark.parametrize("method", ["POST", "PUT", "PATCH", "DELETE"])
def test_ordinary_write_body_is_bounded(client, service, method):
    response = client.request(method, "/api/v1/me", content=b"x" * (65536 + 1))
    assert response.status_code == 413
    assert response.json()["error"]["code"] == "request_too_large"
    service.update_profile.assert_not_called()


def test_readiness_checks_database_and_sanitizes_failure(settings):
    pool = FakePool()
    with TestClient(create_app(settings, pool_factory=lambda settings: pool)) as client:
        assert client.get("/ready").json() == {"status": "ready"}
        pool.conn.execute.side_effect = RuntimeError("private connection credentials")
        response = client.get("/ready")
        assert response.status_code == 503
        assert response.json() == {"status": "unavailable"}
        assert response.headers["cache-control"] == "no-store"
        assert client.get("/health").status_code == 200
