from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_async_session
from app.routers.errors import build_error_detail
from app.schemas.auth import SignUpRequest, SignUpResponse
from app.services.auth_service import AuthService, EmailAlreadyExistsError

router = APIRouter()
async_session_dependency = Depends(get_async_session)


@router.post("/signup", response_model=SignUpResponse, status_code=status.HTTP_201_CREATED)
async def signup(
    payload: SignUpRequest,
    session: AsyncSession = async_session_dependency,
) -> SignUpResponse:
    service = AuthService(session)

    try:
        return await service.signup(email=payload.email, password=payload.password)
    except EmailAlreadyExistsError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=build_error_detail(
                code="EMAIL_ALREADY_EXISTS",
                message="An account with this email already exists.",
            ),
        ) from exc
