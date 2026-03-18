from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_async_session
from app.dependencies.auth import CurrentUser
from app.routers.errors import build_error_detail
from app.schemas.documents import DocumentPublic
from app.services.document_service import DocumentService, FileTooLargeError, InvalidFileTypeError

router = APIRouter()
async_session_dependency = Depends(get_async_session)


@router.post("/upload", response_model=DocumentPublic, status_code=status.HTTP_201_CREATED)
async def upload_document(
    current_user: CurrentUser,
    file: Annotated[UploadFile, File(...)],
    session: AsyncSession = async_session_dependency,
) -> DocumentPublic:
    service = DocumentService(session)

    try:
        return await service.upload_document_for_user(user_id=current_user.id, upload_file=file)
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
