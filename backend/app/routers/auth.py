from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_async_session
from app.dependencies.auth import CurrentUser
from app.routers.errors import build_error_detail
from app.schemas.auth import (
    LoginRequest,
    LoginResponse,
    LogoutResponse,
    SignUpRequest,
    SignUpResponse,
)
from app.services.auth_service import AuthService, EmailAlreadyExistsError, InvalidCredentialsError

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


@router.post("/login", response_model=LoginResponse, status_code=status.HTTP_200_OK)
async def login(
    payload: LoginRequest,
    session: AsyncSession = async_session_dependency,
) -> LoginResponse:
    service = AuthService(session)

    try:
        return await service.login(email=payload.email, password=payload.password)
    except InvalidCredentialsError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=build_error_detail(
                code="INVALID_CREDENTIALS",
                message="Invalid email or password.",
            ),
        ) from exc


@router.post("/logout", response_model=LogoutResponse, status_code=status.HTTP_200_OK)
async def logout(
    current_user: CurrentUser,
    session: AsyncSession = async_session_dependency,
) -> LogoutResponse:
    service = AuthService(session)
    await service.logout(current_user)
    return LogoutResponse(status="ok")
