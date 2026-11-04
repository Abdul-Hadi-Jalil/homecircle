import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException

logger = logging.getLogger(__name__)


class AppError(Exception):
    def __init__(self, status: int, code: str, message: str):
        self.status = status
        self.code = code
        self.message = message


def error_response(status: int, code: str, message: str, *, headers=None):
    return JSONResponse(
        status_code=status,
        content={"error": {"code": code, "message": message}},
        headers=headers,
    )


def install_error_handlers(app: FastAPI):
    @app.exception_handler(AppError)
    async def app_error_handler(request: Request, error: AppError):
        headers = {"WWW-Authenticate": "Bearer"} if error.status == 401 else None
        return error_response(error.status, error.code, error.message, headers=headers)

    @app.exception_handler(RequestValidationError)
    async def validation_handler(request: Request, error: RequestValidationError):
        # Pydantic's raw error input can contain passwords or bearer tokens.
        return error_response(422, "validation_error", "Request validation failed.")

    @app.exception_handler(HTTPException)
    async def http_error_handler(request: Request, error: HTTPException):
        return error_response(
            error.status_code, "http_error", "Request failed.", headers=error.headers
        )

    @app.exception_handler(Exception)
    async def unexpected_error_handler(request: Request, error: Exception):
        # Do not log exception text: database errors may contain connection credentials.
        logger.error("Unhandled request failure (%s)", type(error).__name__)
        return error_response(500, "internal_error", "An unexpected error occurred.")
