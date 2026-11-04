from app.db.pool import user_transaction

COLUMNS = "id, household_id, created_by, expires_at, max_uses, uses_count, revoked_at, created_at"


class InvitationRepository:
    def __init__(self, pool):
        self.pool = pool

    async def consume_attempt(self, user_id):
        # This transaction commits even if the subsequent code lookup fails.
        async with user_transaction(self.pool, user_id) as connection:
            cursor = await connection.execute("SELECT public.consume_invite_attempt() AS allowed")
            return (await cursor.fetchone())["allowed"]

    async def list(self, user_id, household_id, limit, offset):
        async with user_transaction(self.pool, user_id) as connection:
            cursor = await connection.execute(
                f"SELECT {COLUMNS} FROM public.household_invites WHERE household_id = %s "
                "ORDER BY created_at DESC, id LIMIT %s OFFSET %s",
                (household_id, limit, offset),
            )
            return await cursor.fetchall()

    async def issue(self, user_id, household_id, digest, expires, max_uses):
        async with user_transaction(self.pool, user_id) as connection:
            cursor = await connection.execute(
                "SELECT public.issue_household_invite(%s, %s, %s, %s) AS id",
                (household_id, digest, expires, max_uses),
            )
            invitation_id = (await cursor.fetchone())["id"]
            cursor = await connection.execute(
                f"SELECT {COLUMNS} FROM public.household_invites WHERE id = %s",
                (invitation_id,),
            )
            return await cursor.fetchone()

    async def revoke(self, user_id, household_id, invitation_id):
        async with user_transaction(self.pool, user_id) as connection:
            cursor = await connection.execute(
                "SELECT public.revoke_household_invite(%s, %s) AS revoked",
                (household_id, invitation_id),
            )
            return (await cursor.fetchone())["revoked"]

    async def resolve(self, user_id, digest, redeem):
        async with user_transaction(self.pool, user_id) as connection:
            cursor = await connection.execute(
                "SELECT public.resolve_household_invite(%s, %s) AS result",
                (digest, redeem),
            )
            return (await cursor.fetchone())["result"]
