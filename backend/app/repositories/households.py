from uuid import UUID

from app.db.pool import user_transaction


class HouseholdRepository:
    def __init__(self, pool):
        self.pool = pool

    async def list_for_user(self, user_id: UUID):
        async with user_transaction(self.pool, user_id) as connection:
            cursor = await connection.execute(
                "SELECT h.*, m.role, (SELECT count(*) FROM public.household_members c "
                "WHERE c.household_id = h.id) AS member_count FROM public.households h "
                "JOIN public.household_members m ON m.household_id = h.id "
                "WHERE m.user_id = %s ORDER BY h.created_at, h.id",
                (user_id,),
            )
            return await cursor.fetchall()

    async def get_for_user(self, user_id: UUID, household_id: UUID):
        async with user_transaction(self.pool, user_id) as connection:
            cursor = await connection.execute(
                "SELECT h.*, m.role, (SELECT count(*) FROM public.household_members c "
                "WHERE c.household_id = h.id) AS member_count FROM public.households h "
                "JOIN public.household_members m ON m.household_id = h.id "
                "WHERE m.user_id = %s AND h.id = %s",
                (user_id, household_id),
            )
            return await cursor.fetchone()

    async def create(
        self, user_id: UUID, name: str, description: str | None, avatar_key: str | None = None
    ):
        async with user_transaction(self.pool, user_id) as connection:
            cursor = await connection.execute(
                "SELECT * FROM public.create_household(%s, %s)", (name, description)
            )
            household = await cursor.fetchone()
            if avatar_key is not None:
                cursor = await connection.execute(
                    "UPDATE public.households SET avatar_key = %s WHERE id = %s "
                    "RETURNING avatar_key",
                    (avatar_key, household["id"]),
                )
                household = {**household, "avatar_key": (await cursor.fetchone())["avatar_key"]}
            return {**household, "role": "admin"}

    async def profile(self, user_id: UUID):
        async with user_transaction(self.pool, user_id) as connection:
            cursor = await connection.execute(
                "SELECT display_name, avatar_path FROM public.profiles WHERE id = %s", (user_id,)
            )
            return await cursor.fetchone()

    async def update_profile(self, user_id: UUID, display_name: str):
        async with user_transaction(self.pool, user_id) as connection:
            await connection.execute(
                "UPDATE public.profiles SET display_name = %s WHERE id = %s",
                (display_name, user_id),
            )

    async def update_household(
        self, user_id: UUID, household_id: UUID, name: str, description, avatar_key=None
    ):
        async with user_transaction(self.pool, user_id) as connection:
            cursor = await connection.execute(
                "UPDATE public.households SET name = %s, description = %s, "
                "avatar_key = coalesce(%s, avatar_key) WHERE id = %s RETURNING id",
                (name, description, avatar_key, household_id),
            )
            return await cursor.fetchone() is not None

    async def set_member_role(self, user_id: UUID, household_id: UUID, target: UUID, role: str):
        async with user_transaction(self.pool, user_id) as connection:
            await connection.execute(
                "SELECT public.set_member_role(%s, %s, %s)", (household_id, target, role)
            )

    async def remove_member(self, user_id: UUID, household_id: UUID, target: UUID):
        async with user_transaction(self.pool, user_id) as connection:
            await connection.execute(
                "SELECT public.remove_household_member(%s, %s)", (household_id, target)
            )

    async def leave(self, user_id: UUID, household_id: UUID):
        async with user_transaction(self.pool, user_id) as connection:
            await connection.execute("SELECT public.leave_household(%s)", (household_id,))

    async def delete_household(self, user_id: UUID, household_id: UUID):
        async with user_transaction(self.pool, user_id) as connection:
            cursor = await connection.execute(
                "DELETE FROM public.households WHERE id = %s RETURNING id", (household_id,)
            )
            return await cursor.fetchone() is not None

    async def members(self, user_id: UUID, household_id: UUID, limit: int, offset: int):
        async with user_transaction(self.pool, user_id) as connection:
            cursor = await connection.execute(
                "SELECT * FROM public.list_household_members(%s, %s, %s)",
                (household_id, limit, offset),
            )
            return await cursor.fetchall()
