from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

TaskType = Literal["repair", "chore", "general"]
Priority = Literal["low", "normal", "high", "urgent"]
Status = Literal["open", "in_progress", "blocked", "completed", "cancelled"]


class Input(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class Revision(Input):
    expected_revision: int = Field(ge=1)


class TaskFields(Input):
    task_type: TaskType = "general"
    title: str = Field(min_length=1, max_length=150)
    description: str | None = Field(default=None, max_length=8000)
    priority: Priority = "normal"
    assigned_to: UUID | None = None
    due_date: date | None = None
    location: str | None = Field(default=None, max_length=150)
    linked_inventory_item_id: UUID | None = None

    @model_validator(mode="after")
    def repair_link(self):
        if self.linked_inventory_item_id and self.task_type != "repair":
            raise ValueError("Only repairs can link inventory")
        return self


class TaskCreate(TaskFields):
    pass


class TaskUpdate(Revision):
    task_type: TaskType | None = None
    title: str | None = Field(default=None, min_length=1, max_length=150)
    description: str | None = Field(default=None, max_length=8000)
    priority: Priority | None = None
    assigned_to: UUID | None = None
    due_date: date | None = None
    location: str | None = Field(default=None, max_length=150)
    linked_inventory_item_id: UUID | None = None


class TaskResponse(BaseModel):
    id: UUID
    household_id: UUID
    task_type: Literal["repair", "chore", "general", "shopping"]
    title: str
    description: str | None
    priority: Priority
    status: Status
    created_by: UUID | None
    assigned_to: UUID | None
    updated_by: UUID | None
    creator_name: str | None = None
    assignee_name: str | None = None
    due_date: date | None
    location: str | None
    linked_inventory_item_id: UUID | None
    linked_inventory_name: str | None = None
    linked_inventory_type: str | None = None
    completion_note: str | None
    completed_at: datetime | None
    cancelled_at: datetime | None
    revision: int
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None


class TaskPage(BaseModel):
    items: list[TaskResponse]
    total: int
    page: int
    page_size: int


class Assignment(Revision):
    operation: Literal["assign", "unassign", "claim"]
    assigned_to: UUID | None = None

    @model_validator(mode="after")
    def target(self):
        if (self.operation == "assign") != (self.assigned_to is not None):
            raise ValueError("Only assign takes an assignee")
        return self


class PriorityUpdate(Revision):
    priority: Priority


class StatusUpdate(Revision):
    status: Status
    reopen: bool = False
    completion_note: str | None = Field(default=None, max_length=4000)


class CommentCreate(Revision):
    body: str = Field(min_length=1, max_length=4000)


class CommentUpdate(CommentCreate):
    expected_comment_revision: int = Field(ge=1)


class CommentResponse(BaseModel):
    id: UUID
    household_id: UUID
    task_id: UUID
    author_user_id: UUID | None
    author_name: str | None = None
    body: str
    revision: int
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None


class CommentPage(BaseModel):
    items: list[CommentResponse]
    page: int
    page_size: int


class AttachmentUpload(Revision):
    comment_id: UUID | None = None
    data_base64: str = Field(min_length=1, max_length=7_000_000)


class AttachmentResponse(BaseModel):
    id: UUID
    household_id: UUID
    task_id: UUID
    comment_id: UUID | None
    uploaded_by: UUID | None
    content_type: str
    size_bytes: int
    created_at: datetime


class AttachmentPage(BaseModel):
    items: list[AttachmentResponse]
    page: int
    page_size: int


class AttachmentURL(BaseModel):
    url: str
    expires_in: int


class ActivityResponse(BaseModel):
    id: UUID
    actor_user_id: UUID | None
    actor_name: str | None = None
    action: str
    changes: dict
    created_at: datetime


class ActivityPage(BaseModel):
    items: list[ActivityResponse]
    page: int
    page_size: int
