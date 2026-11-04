import ssl
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import router
from app.core.config import Settings, get_settings
from app.core.exceptions import install_error_handlers
from app.core.security import TokenVerifier
from app.db.pool import create_pool, verify_database_role


def create_app(settings: Settings | None = None, *, pool_factory=create_pool) -> FastAPI:
    settings = settings or get_settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        pool = pool_factory(settings)
        app.state.pool = pool
        async with httpx.AsyncClient(
            timeout=10, follow_redirects=False, verify=ssl.create_default_context()
        ) as client:
            app.state.token_verifier = TokenVerifier(settings, client)
            try:
                await pool.open(wait=True, timeout=settings.database_connect_timeout)
                await verify_database_role(pool)
                yield
            finally:
                await pool.close()

    app = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        lifespan=lifespan,
        docs_url="/docs" if settings.app_env != "production" else None,
        redoc_url=None,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_allowed_origins,
        allow_credentials=False,
        allow_methods=["GET", "POST", "PATCH", "PUT", "DELETE"],
        allow_headers=["Authorization", "Content-Type"],
    )
    install_error_handlers(app)
    app.include_router(router)

    @app.get("/health", tags=["health"])
    async def health():
        return {"status": "ok"}

    return app
