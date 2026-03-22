from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_async_session
from app.dependencies.auth import CurrentUser
from app.routers.errors import build_error_detail
from app.services.user_service import UserDeletionError, UserService

router = APIRouter()
async_session_dependency = Depends(get_async_session)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_me(
    current_user: CurrentUser,
    session: AsyncSession = async_session_dependency,
) -> Response:
    service = UserService(session)

    try:
        await service.delete_account(user_id=current_user.id)
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    except UserDeletionError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=build_error_detail(
                code="USER_DELETION_FAILED",
                message="Failed to delete account resources.",
            ),
        ) from exc
