from typing import Annotated
from uuid import UUID

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    File,
    HTTPException,
    Query,
    Response,
    UploadFile,
    status,
)
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_async_session
from app.dependencies.auth import CurrentUser
from app.routers.errors import build_error_detail
from app.schemas.documents import DocumentListResponse, DocumentPublic
from app.services.document_service import (
    DocumentDeletionError,
    DocumentNotFoundError,
    DocumentService,
    FileTooLargeError,
    InvalidFileTypeError,
)
from app.services.processing.pipeline import process_document_pipeline

router = APIRouter()
async_session_dependency = Depends(get_async_session)


@router.post("/upload", response_model=DocumentPublic, status_code=status.HTTP_201_CREATED)
async def upload_document(
    current_user: CurrentUser,
    background_tasks: BackgroundTasks,
    file: Annotated[UploadFile, File(...)],
    session: AsyncSession = async_session_dependency,
) -> DocumentPublic:
    service = DocumentService(session)

    try:
        document, document_id = await service.upload_document_for_user(
            user_id=current_user.id,
            upload_file=file,
        )
        background_tasks.add_task(process_document_pipeline, document_id=document_id)
        return document
    except InvalidFileTypeError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=build_error_detail(
                code="INVALID_FILE_TYPE",
                message="Only PDF files are supported",
            ),
        ) from exc
    except FileTooLargeError as exc:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=build_error_detail(
                code="FILE_TOO_LARGE",
                message="Uploaded file exceeds the 50 MB limit",
            ),
        ) from exc


@router.get("", response_model=DocumentListResponse)
async def list_documents(
    current_user: CurrentUser,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1),
    search: str | None = Query(default=None),
    session: AsyncSession = async_session_dependency,
) -> DocumentListResponse:
    service = DocumentService(session)
    return await service.list_documents_for_user(
        user_id=current_user.id,
        page=page,
        page_size=page_size,
        search=search,
    )


@router.get("/{document_id}", response_model=DocumentPublic)
async def get_document(
    document_id: UUID,
    current_user: CurrentUser,
    session: AsyncSession = async_session_dependency,
) -> DocumentPublic:
    service = DocumentService(session)

    try:
        return await service.get_document_for_user(
            user_id=current_user.id,
            document_id=document_id,
        )
    except DocumentNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=build_error_detail(
                code="DOCUMENT_NOT_FOUND",
                message="Document not found.",
            ),
        ) from exc


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    document_id: UUID,
    current_user: CurrentUser,
    session: AsyncSession = async_session_dependency,
) -> Response:
    service = DocumentService(session)

    try:
        await service.delete_document_for_user(
            user_id=current_user.id,
            document_id=document_id,
        )
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    except DocumentNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=build_error_detail(
                code="DOCUMENT_NOT_FOUND",
                message="Document not found.",
            ),
        ) from exc
    except DocumentDeletionError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=build_error_detail(
                code="DOCUMENT_DELETION_FAILED",
                message="Failed to delete document resources.",
            ),
        ) from exc
