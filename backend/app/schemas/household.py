from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class HouseholdCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=1000)

    @field_validator("name")
    @classmethod
    def nonblank_name(cls, value: str):
        value = value.strip()
        if not value:
            raise ValueError("Household name cannot be blank")
        return value


class Household(BaseModel):
    id: UUID
    name: str
    description: str | None
    image_path: str | None
    created_by: UUID | None
    created_at: datetime
    updated_at: datetime
    role: Literal["admin", "member"]
    member_count: int = 1


class Me(BaseModel):
    id: UUID
    display_name: str
    email: str | None
    households: list[Household]
    avatar_path: str | None = None


class ProfileUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    display_name: str = Field(min_length=1, max_length=100)


class HouseholdUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    name: str = Field(min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=1000)


class Member(BaseModel):
    user_id: UUID
    display_name: str
    avatar_path: str | None
    role: Literal["admin", "member"]
    joined_at: datetime
