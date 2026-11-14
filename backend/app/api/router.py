from fastapi import APIRouter

from app.api.v1.households import router as household_router
from app.api.v1.inventory import router as inventory_router
from app.api.v1.invitations import router as invitation_router
from app.api.v1.shopping import router as shopping_router
from app.api.v1.tasks import router as task_router

router = APIRouter(prefix="/api/v1")
router.include_router(household_router)
router.include_router(invitation_router)
router.include_router(inventory_router)
router.include_router(task_router)
router.include_router(shopping_router)


@router.get("/health", tags=["health"])
async def api_health():
    return {"status": "ok", "api_version": "v1"}
