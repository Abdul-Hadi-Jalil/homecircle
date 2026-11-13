from datetime import UTC, date, datetime
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, Response

from app.api.v1.households import User
from app.core.config import get_settings
from app.repositories.tasks import TaskRepository
from app.schemas.task import (
    ActivityPage,
    Assignment,
    AttachmentPage,
    AttachmentResponse,
    AttachmentUpload,
    AttachmentURL,
    CommentCreate,
    CommentPage,
    CommentResponse,
    CommentUpdate,
    Priority,
    PriorityUpdate,
    Revision,
    Status,
    StatusUpdate,
    TaskCreate,
    TaskPage,
    TaskResponse,
    TaskUpdate,
)
from app.services.task_photos import TaskPhotos
from app.services.tasks import TaskService

router = APIRouter(prefix="/households/{household_id}", tags=["tasks"])


def get_task_service(request: Request):
    return TaskService(TaskRepository(request.app.state.pool))


Service = Annotated[TaskService, Depends(get_task_service)]


def get_task_photos(service: Service):
    return TaskPhotos(service.repository, get_settings())


Photos = Annotated[TaskPhotos, Depends(get_task_photos)]


def task_filters(
    search: str = Query("", max_length=150),
    task_type: Literal["repair", "chore", "general", "shopping"] | None = None,
    priority: Priority | None = None,
    status: Status | None = None,
    assignment: Literal["all", "me", "unassigned"] = "all",
    assigned_to: UUID | None = None,
    due_before: date | None = None,
    due_after: date | None = None,
    overdue: bool = False,
    archived: bool = False,
    sort: Literal["priority", "due_date", "updated", "created"] = "priority",
    page: int = Query(1, ge=1, le=100000),
    page_size: int = Query(20, ge=1, le=100),
    as_of: date | None = None,
    linked_inventory_item_id: UUID | None = None,
):
    return {
        "search": search,
        "task_type": task_type,
        "priority": priority,
        "status": status,
        "assignment": assignment,
        "assigned_to": assigned_to,
        "due_before": due_before,
        "due_after": due_after,
        "overdue": overdue,
        "archived": archived,
        "sort": sort,
        "page": page,
        "page_size": page_size,
        "as_of": as_of or datetime.now(UTC).date(),
        "linked_inventory": linked_inventory_item_id,
    }


Filters = Annotated[dict, Depends(task_filters)]


@router.get("/tasks", response_model=TaskPage)
async def list_tasks(household_id: UUID, user: User, service: Service, filters: Filters):
    return await service.list(user, household_id, filters)


@router.post("/tasks", response_model=TaskResponse, status_code=201)
async def create_task(household_id: UUID, data: TaskCreate, user: User, service: Service):
    return await service.create(user, household_id, data)


@router.get("/tasks/summary", response_model=dict[str, int])
async def summary(household_id: UUID, user: User, service: Service, as_of: date | None = None):
    return await service.summary(user, household_id, as_of or datetime.now(UTC).date())


@router.get("/inventory/{item_id}/tasks", response_model=TaskPage)
async def related(
    household_id: UUID, item_id: UUID, user: User, service: Service, filters: Filters
):
    return await service.related(user, household_id, item_id, filters)


@router.get("/tasks/{task_id}", response_model=TaskResponse)
async def detail(household_id: UUID, task_id: UUID, user: User, service: Service):
    return await service.detail(user, household_id, task_id)


@router.patch("/tasks/{task_id}", response_model=TaskResponse)
async def update(household_id: UUID, task_id: UUID, data: TaskUpdate, user: User, service: Service):
    return await service.update(user, household_id, task_id, data)


@router.delete("/tasks/{task_id}", response_model=TaskResponse)
async def archive(
    household_id: UUID,
    task_id: UUID,
    user: User,
    service: Service,
    expected_revision: int = Query(ge=1),
):
    return await service.archive(user, household_id, task_id, expected_revision)


@router.post("/tasks/{task_id}/restore", response_model=TaskResponse)
async def restore(household_id: UUID, task_id: UUID, user: User, service: Service, data: Revision):
    return await service.archive(user, household_id, task_id, data.expected_revision, restore=True)


@router.patch("/tasks/{task_id}/assignment", response_model=TaskResponse)
async def assignment(
    household_id: UUID, task_id: UUID, data: Assignment, user: User, service: Service
):
    return await service.assignment(user, household_id, task_id, data)


@router.patch("/tasks/{task_id}/priority", response_model=TaskResponse)
async def priority(
    household_id: UUID, task_id: UUID, data: PriorityUpdate, user: User, service: Service
):
    return await service.priority(user, household_id, task_id, data)


@router.patch("/tasks/{task_id}/status", response_model=TaskResponse)
async def status(
    household_id: UUID, task_id: UUID, data: StatusUpdate, user: User, service: Service
):
    return await service.status(user, household_id, task_id, data)


@router.get("/tasks/{task_id}/comments", response_model=CommentPage)
async def comments(
    household_id: UUID,
    task_id: UUID,
    user: User,
    service: Service,
    page: int = Query(1, ge=1, le=100000),
    page_size: int = Query(20, ge=1, le=100),
):
    return await service.comments(user, household_id, task_id, page, page_size)


@router.post("/tasks/{task_id}/comments", response_model=CommentResponse, status_code=201)
async def add_comment(
    household_id: UUID, task_id: UUID, data: CommentCreate, user: User, service: Service
):
    return await service.add_comment(user, household_id, task_id, data)


@router.patch("/tasks/{task_id}/comments/{comment_id}", response_model=CommentResponse)
async def edit_comment(
    household_id: UUID,
    task_id: UUID,
    comment_id: UUID,
    data: CommentUpdate,
    user: User,
    service: Service,
):
    return await service.change_comment(
        user,
        household_id,
        task_id,
        comment_id,
        data.expected_revision,
        data.expected_comment_revision,
        data.body,
    )


@router.delete("/tasks/{task_id}/comments/{comment_id}", response_model=CommentResponse)
async def delete_comment(
    household_id: UUID,
    task_id: UUID,
    comment_id: UUID,
    user: User,
    service: Service,
    expected_revision: int = Query(ge=1),
    expected_comment_revision: int = Query(ge=1),
):
    return await service.change_comment(
        user, household_id, task_id, comment_id, expected_revision, expected_comment_revision
    )


@router.get("/tasks/{task_id}/activity", response_model=ActivityPage)
async def activity(
    household_id: UUID,
    task_id: UUID,
    user: User,
    service: Service,
    page: int = Query(1, ge=1, le=100000),
    page_size: int = Query(20, ge=1, le=100),
):
    return await service.activity(user, household_id, task_id, page, page_size)


@router.get("/tasks/{task_id}/attachments", response_model=AttachmentPage)
async def attachments(
    household_id: UUID,
    task_id: UUID,
    user: User,
    service: Service,
    page: int = Query(1, ge=1, le=100000),
    page_size: int = Query(20, ge=1, le=100),
):
    return await service.attachments(user, household_id, task_id, page, page_size)


@router.post("/tasks/{task_id}/attachments", response_model=AttachmentResponse, status_code=201)
async def upload(
    household_id: UUID,
    task_id: UUID,
    data: AttachmentUpload,
    user: User,
    photos: Photos,
    request: Request,
    response: Response,
):
    response.headers["Cache-Control"] = "no-store"
    return await photos.upload(user, household_id, task_id, data, request.headers["authorization"])


@router.get("/tasks/{task_id}/attachments/{attachment_id}/url", response_model=AttachmentURL)
async def read_url(
    household_id: UUID,
    task_id: UUID,
    attachment_id: UUID,
    user: User,
    photos: Photos,
    request: Request,
    response: Response,
):
    response.headers["Cache-Control"] = "no-store"
    return await photos.read_url(
        user, household_id, task_id, attachment_id, request.headers["authorization"]
    )


@router.delete("/tasks/{task_id}/attachments/{attachment_id}", response_model=TaskResponse)
async def remove_attachment(
    household_id: UUID,
    task_id: UUID,
    attachment_id: UUID,
    user: User,
    photos: Photos,
    request: Request,
    expected_revision: int = Query(ge=1),
):
    return await photos.remove(
        user,
        household_id,
        task_id,
        attachment_id,
        expected_revision,
        request.headers["authorization"],
    )
