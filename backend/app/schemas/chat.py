from typing import Literal
from uuid import UUID

from pydantic import Field, model_validator

from app.schemas.shopping import ShoppingCreate
from app.schemas.task import Input, Revision, TaskCreate

Emoji = Literal["👍", "❤️", "😂", "😮", "😢", "🙏"]


class MessageCreate(Input):
    client_message_id: UUID
    message_type: Literal["text", "image", "task_share"] = "text"
    body: str | None = Field(default=None, max_length=4000)
    reply_to_message_id: UUID | None = None
    linked_task_id: UUID | None = None
    attachment_ids: list[UUID] = Field(default_factory=list, max_length=1)

    @model_validator(mode="after")
    def content(self):
        if self.message_type == "text" and (
            not self.body or self.linked_task_id or self.attachment_ids
        ):
            raise ValueError("Text message requires text only")
        if self.message_type == "task_share" and (not self.linked_task_id or self.attachment_ids):
            raise ValueError("Task share requires a task")
        if self.message_type == "image" and (len(self.attachment_ids) != 1 or self.linked_task_id):
            raise ValueError("Image message requires one finalized image")
        return self


class MessageEdit(Revision):
    body: str = Field(min_length=1, max_length=4000)


class Reaction(Input):
    emoji: Emoji


class ChatUpload(Input):
    client_message_id: UUID
    attachment_id: UUID
    data_base64: str = Field(min_length=1, max_length=7_000_000)


class ShareTask(Input):
    client_message_id: UUID
    task_id: UUID
    body: str | None = Field(default=None, max_length=4000)


class TaskConversion(Revision):
    client_request_id: UUID
    task_type: Literal["repair", "chore", "general", "shopping"]
    fields: dict

    def creation(self):
        return (
            ShoppingCreate.model_validate(self.fields)
            if self.task_type == "shopping"
            else TaskCreate.model_validate({**self.fields, "task_type": self.task_type})
        )

    @model_validator(mode="after")
    def valid_task(self):
        self.creation()
        return self
