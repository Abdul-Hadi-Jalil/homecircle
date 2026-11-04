from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.exceptions import AppError
from app.core.security import TokenVerifier
from app.models.auth import AuthenticatedUser

bearer = HTTPBearer(auto_error=False)


def get_token_verifier(request: Request) -> TokenVerifier:
    return request.app.state.token_verifier


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    verifier: Annotated[TokenVerifier, Depends(get_token_verifier)],
) -> AuthenticatedUser:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise AppError(401, "unauthorized", "A valid access token is required.")
    return await verifier.verify(credentials.credentials)
