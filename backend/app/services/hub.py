from app.core.exceptions import AppError


class HubService:
    def __init__(self, repository):
        self.repository = repository

    async def dashboard(self, actor, household):
        return await self.repository.dashboard(actor, household)

    async def zone(self, actor, household, zone):
        return await self.repository.zone(actor, household, zone)

    async def notifications(self, actor, household, unread, cursor, size):
        return await self.repository.notifications(actor, household, unread, cursor, size)

    async def unread(self, actor, household):
        return await self.repository.unread(actor, household)

    async def notification(self, actor, identity, action=None):
        return await self.repository.notification(actor, identity, action)

    async def read_all(self, actor, household):
        return await self.repository.read_all(actor, household)

    async def preferences(self, actor, household, fields=None):
        return await self.repository.preferences(actor, household, fields)

    async def register(self, actor, data):
        return await self.repository.register(actor, data)

    async def revoke(self, actor, installation):
        return await self.repository.revoke(actor, installation)

    async def activity(self, actor, household, category, event_type, start, end, cursor, size):
        if (
            (start and start.tzinfo is None)
            or (end and end.tzinfo is None)
            or (start and end and start >= end)
        ):
            raise AppError(
                422, "validation_error", "Use a valid timezone-aware activity date range."
            )
        return await self.repository.activity(
            actor, household, category, event_type, start, end, cursor, size
        )
