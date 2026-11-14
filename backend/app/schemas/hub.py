from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, model_validator

from app.schemas.task import Input

Category = Literal["inventory", "shopping", "tasks", "repairs", "members"]
Entity = Literal["inventory", "task", "shopping", "chat", "household"]


class Summary(BaseModel):
    pending_tasks: int
    urgent_issues: int
    shopping_items: int
    low_stock_items: int
    out_of_stock_items: int
    overdue_tasks: int
    my_tasks: int


class HubHousehold(BaseModel):
    id: UUID
    name: str
    time_zone: str


class Attention(BaseModel):
    id: UUID
    household_id: UUID
    entity_type: Entity
    title: str
    task_type: str | None = None
    priority: str | None = None
    status: str
    due_date: date | None = None
    assignee_name: str | None = None
    rank: int


class FamilyEvent(BaseModel):
    id: UUID
    household_id: UUID
    actor_user_id: UUID | None
    actor_display_name: str | None
    event_type: str
    category: Category
    entity_type: Entity
    entity_id: UUID
    title: str
    created_at: datetime
    metadata: dict = Field(default_factory=dict)


class Dashboard(BaseModel):
    household: HubHousehold
    summary: Summary
    needs_attention: list[Attention]
    upcoming_tasks: list[Attention]
    recent_activity: list[FamilyEvent]
    unread_notifications: int
    as_of_date: date
    refreshed_at: datetime
    has_records: bool


class Notification(BaseModel):
    id: UUID
    recipient_user_id: UUID
    household_id: UUID
    event_type: str
    title: str
    body: str
    related_entity_type: Entity
    related_entity_id: UUID
    source_event_id: UUID
    created_at: datetime
    read_at: datetime | None
    dismissed_at: datetime | None


class ActivityPage(BaseModel):
    items: list[FamilyEvent]
    cursor: str | None
    has_more: bool


class NotificationPage(BaseModel):
    items: list[Notification]
    cursor: str | None
    has_more: bool


class PreferencesPatch(Input):
    tasks_enabled: bool | None = None
    shopping_enabled: bool | None = None
    inventory_enabled: bool | None = None
    chat_enabled: bool | None = None
    mentions_enabled: bool | None = None
    push_enabled: bool | None = None

    @model_validator(mode="after")
    def no_null(self):
        if any(getattr(self, key) is None for key in self.model_fields_set):
            raise ValueError("Preference values cannot be null")
        return self


class Preferences(BaseModel):
    user_id: UUID
    household_id: UUID
    tasks_enabled: bool = True
    shopping_enabled: bool = True
    inventory_enabled: bool = True
    chat_enabled: bool = True
    mentions_enabled: bool = True
    push_enabled: bool = True
    updated_at: datetime | None = None


class DeviceRegistration(Input):
    token: str = Field(min_length=20, max_length=4096, pattern=r"^[A-Za-z0-9_:.-]+$", repr=False)
    platform: Literal["android", "ios"] = "android"
    device_identifier: UUID


class DeviceRemoval(Input):
    device_identifier: UUID


class ReadAll(Input):
    household_id: UUID | None = None


class HouseholdZone(Input):
    time_zone: str = Field(min_length=1, max_length=100)
