from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, Response

from app.api.v1.households import User
from app.api.v1.shopping import precise
from app.core.config import get_settings
from app.core.exceptions import AppError
from app.repositories.chat import ChatRepository
from app.schemas.chat import (
    ChatUpload,
    Emoji,
    MessageCreate,
    MessageEdit,
    Reaction,
    ShareTask,
    TaskConversion,
)
from app.services.chat import ChatService
from app.services.chat_photos import ChatPhotos

router = APIRouter(prefix="/households/{household_id}/chat", tags=["chat"])


def get_chat(request: Request):
    repository = ChatRepository(request.app.state.pool)
    settings = get_settings()
    return ChatService(repository, settings, ChatPhotos(repository, settings))


Service = Annotated[ChatService, Depends(get_chat)]


@router.get("/messages")
async def messages(
    household_id: UUID,
    user: User,
    service: Service,
    before: str | None = Query(None, max_length=500),
    after: str | None = Query(None, max_length=500),
    limit: int = Query(30, ge=1, le=100),
):
    if before and after:
        raise AppError(422, "invalid_cursor", "Choose either before or after.")
    return precise(await service.repository.listing(user.id, household_id, before, after, limit))


@router.get("/changes")
async def changes(
    household_id: UUID,
    user: User,
    service: Service,
    after: int = Query(0, ge=0, le=9223372036854775807),
    limit: int = Query(100, ge=1, le=200),
):
    return precise(await service.repository.changes(user.id, household_id, after, limit))


@router.post("/messages", status_code=201)
async def send(
    household_id: UUID,
    data: MessageCreate,
    user: User,
    service: Service,
    request: Request,
    response: Response,
):
    message, created = await service.send(
        user, household_id, data, request.headers.get("authorization")
    )
    response.status_code = 201 if created else 200
    return precise(message)


@router.get("/messages/{message_id}")
async def detail(household_id: UUID, message_id: UUID, user: User, service: Service):
    return precise(await service.detail(user, household_id, message_id))


@router.patch("/messages/{message_id}")
async def edit(
    household_id: UUID, message_id: UUID, data: MessageEdit, user: User, service: Service
):
    return precise(await service.edit(user, household_id, message_id, data))


@router.delete("/messages/{message_id}")
async def delete(
    household_id: UUID,
    message_id: UUID,
    user: User,
    service: Service,
    request: Request,
    expected_revision: int = Query(ge=1),
):
    message, paths = await service.delete(user, household_id, message_id, expected_revision)
    for path in paths:
        await service.photos.cleanup(
            user, household_id, path["storage_path"], request.headers.get("authorization")
        )
    return precise(message)


@router.put("/messages/{message_id}/reactions")
async def react(household_id: UUID, message_id: UUID, data: Reaction, user: User, service: Service):
    return precise(await service.react(user, household_id, message_id, data.emoji))


@router.delete("/messages/{message_id}/reactions/{emoji}")
async def unreact(household_id: UUID, message_id: UUID, emoji: Emoji, user: User, service: Service):
    return precise(await service.react(user, household_id, message_id, emoji, True))


@router.post("/share-task", status_code=201)
async def share(
    household_id: UUID, data: ShareTask, user: User, service: Service, response: Response
):
    message, created = await service.send(
        user,
        household_id,
        MessageCreate(
            client_message_id=data.client_message_id,
            message_type="task_share",
            linked_task_id=data.task_id,
            body=data.body,
        ),
    )
    response.status_code = 201 if created else 200
    return precise(message)


@router.post("/messages/{message_id}/create-task", status_code=201)
async def convert(
    household_id: UUID, message_id: UUID, data: TaskConversion, user: User, service: Service
):
    return precise(await service.convert(user, household_id, message_id, data))


@router.post("/attachments", status_code=201)
async def upload(
    household_id: UUID,
    data: ChatUpload,
    user: User,
    service: Service,
    request: Request,
    response: Response,
):
    response.headers["Cache-Control"] = "no-store"
    return precise(
        await service.photos.upload_image(
            user, household_id, data, request.headers.get("authorization")
        )
    )


@router.get("/attachments/{attachment_id}/url")
async def image_url(
    household_id: UUID,
    attachment_id: UUID,
    user: User,
    service: Service,
    request: Request,
    response: Response,
):
    response.headers["Cache-Control"] = "no-store"
    return await service.photos.read_url(
        user, household_id, attachment_id, request.headers.get("authorization")
    )


@router.delete("/attachments/{attachment_id}")
async def remove_image(
    household_id: UUID,
    attachment_id: UUID,
    user: User,
    service: Service,
    request: Request,
    expected_revision: int = Query(ge=1),
):
    async with service.repository.transaction(user.id, household_id) as c:
        row = await (
            await c.execute(
                "SELECT message_id FROM public.message_attachments WHERE household_id=%s AND id=%s",
                (household_id, attachment_id),
            )
        ).fetchone()
        if not row:
            raise AppError(404, "not_found", "Image not found.")
    message, paths = await service.delete(user, household_id, row["message_id"], expected_revision)
    for path in paths:
        await service.photos.cleanup(
            user, household_id, path["storage_path"], request.headers.get("authorization")
        )
    return precise(message)
