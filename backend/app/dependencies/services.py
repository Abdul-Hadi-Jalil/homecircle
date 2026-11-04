from fastapi import Request

from app.repositories.households import HouseholdRepository
from app.services.households import HouseholdService


def get_household_service(request: Request) -> HouseholdService:
    return HouseholdService(HouseholdRepository(request.app.state.pool))
