import asyncio
import time
from typing import Any
from uuid import UUID

import httpx
import jwt

from app.core.config import Settings
from app.core.exceptions import AppError
from app.models.auth import AuthenticatedUser


class TokenVerifier:
    """Only configured algorithms and verified claims can establish an identity."""

    def __init__(self, settings: Settings, client: httpx.AsyncClient):
        self.settings = settings
        self.client = client
        self._keys: list[dict[str, Any]] = []
        self._expires_at = 0.0
        self._lock = asyncio.Lock()

    async def _signing_key(self, kid: str, algorithm: str):
        async with self._lock:
            if time.monotonic() >= self._expires_at:
                try:
                    response = await self.client.get(
                        f"{self.settings.supabase_url}/auth/v1/.well-known/jwks.json"
                    )
                    response.raise_for_status()
                    self._keys = response.json()["keys"]
                    if not isinstance(self._keys, list):
                        raise ValueError("Invalid JWKS")
                    if any(not isinstance(key, dict) for key in self._keys):
                        raise ValueError("Invalid JWKS keys")
                    self._expires_at = time.monotonic() + 300
                except (httpx.HTTPError, ValueError, KeyError) as error:
                    raise AppError(
                        503, "auth_unavailable", "Authentication is unavailable."
                    ) from error
            for key in self._keys:
                if key.get("kid") == kid and key.get("alg") == algorithm:
                    return jwt.PyJWK.from_dict(key, algorithm=algorithm).key
        # Unknown keys fail closed until the bounded cache expires; avoids attacker-driven fetches.
        raise jwt.InvalidTokenError("Unknown signing key")

    async def verify(self, token: str) -> AuthenticatedUser:
        try:
            header = jwt.get_unverified_header(token)  # Selection only, never identity.
            if self.settings.supabase_jwt_mode == "legacy_hs256":
                algorithm = "HS256"
                if header.get("alg") != algorithm:
                    raise jwt.InvalidAlgorithmError()
                key = self.settings.supabase_jwt_secret.get_secret_value()
            else:
                algorithm = header.get("alg")
                if algorithm not in ("ES256", "RS256") or not isinstance(header.get("kid"), str):
                    raise jwt.InvalidAlgorithmError()
                key = await self._signing_key(header["kid"], algorithm)
            claims = jwt.decode(
                token,
                key,
                algorithms=[algorithm],
                issuer=self.settings.supabase_jwt_issuer,
                audience=self.settings.supabase_jwt_audience,
                options={"require": ["exp", "iat", "sub", "iss", "aud", "role"]},
            )
            if claims["role"] != "authenticated":
                raise jwt.InvalidTokenError("Not a user access token")
            email = claims.get("email")
            return AuthenticatedUser(
                id=UUID(claims["sub"]), email=email if isinstance(email, str) else None
            )
        except (jwt.PyJWTError, ValueError, TypeError, KeyError) as error:
            raise AppError(401, "unauthorized", "A valid access token is required.") from error
