import json
import time

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec

from app.core.exceptions import AppError
from app.core.security import TokenVerifier
from tests.conftest import USER_ID


@pytest.fixture
def signing_key():
    return ec.generate_private_key(ec.SECP256R1())


def claims(**overrides):
    return {
        "sub": str(USER_ID),
        "email": "person@example.test",
        "role": "authenticated",
        "iss": "https://test.supabase.co/auth/v1",
        "aud": "authenticated",
        "iat": int(time.time()),
        "exp": int(time.time()) + 120,
        **overrides,
    }


def token(key, **overrides):
    return jwt.encode(claims(**overrides), key, algorithm="ES256", headers={"kid": "test-key"})


def jwks_transport(key):
    jwk = json.loads(jwt.algorithms.ECAlgorithm.to_jwk(key.public_key()))
    jwk.update({"kid": "test-key", "alg": "ES256", "use": "sig"})
    return httpx.MockTransport(lambda request: httpx.Response(200, json={"keys": [jwk]}))


async def test_asymmetric_signature_is_verified(settings, signing_key):
    async with httpx.AsyncClient(transport=jwks_transport(signing_key)) as client:
        verified = await TokenVerifier(settings, client).verify(token(signing_key))
    assert verified.id == USER_ID
    assert verified.email == "person@example.test"


@pytest.mark.parametrize(
    "overrides",
    [
        {"exp": 1},
        {"iss": "https://attacker.example/auth/v1"},
        {"aud": "other"},
        {"sub": "invalid"},
        {"role": "service_role"},
        {"iat": int(time.time()) + 600},
    ],
)
async def test_invalid_claims_rejected(settings, signing_key, overrides):
    async with httpx.AsyncClient(transport=jwks_transport(signing_key)) as client:
        with pytest.raises(AppError) as error:
            await TokenVerifier(settings, client).verify(token(signing_key, **overrides))
    assert error.value.status == 401


async def test_wrong_signature_and_malformed_tokens(settings, signing_key):
    forged = token(ec.generate_private_key(ec.SECP256R1()))
    async with httpx.AsyncClient(transport=jwks_transport(signing_key)) as client:
        verifier = TokenVerifier(settings, client)
        for value in [forged, "not.a.token", "", jwt.encode(claims(), "x" * 32, algorithm="HS256")]:
            with pytest.raises(AppError) as error:
                await verifier.verify(value)
            assert error.value.status == 401


async def test_legacy_hs256_uses_explicit_server_secret(settings):
    settings.supabase_jwt_mode = "legacy_hs256"
    from pydantic import SecretStr

    settings.supabase_jwt_secret = SecretStr("test-only-secret-" * 4)
    async with httpx.AsyncClient() as client:
        verifier = TokenVerifier(settings, client)
        signed = jwt.encode(
            claims(), settings.supabase_jwt_secret.get_secret_value(), algorithm="HS256"
        )
        assert (await verifier.verify(signed)).id == USER_ID
        with pytest.raises(AppError):
            await verifier.verify(jwt.encode(claims(), "wrong-secret-" * 4, algorithm="HS256"))


async def test_jwks_outage_fails_closed(settings, signing_key):
    async with httpx.AsyncClient(
        transport=httpx.MockTransport(lambda request: httpx.Response(503))
    ) as client:
        with pytest.raises(AppError) as error:
            await TokenVerifier(settings, client).verify(token(signing_key))
    assert error.value.status == 503
