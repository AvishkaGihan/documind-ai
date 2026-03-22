from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import ExpiredSignatureError, JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_async_session
from app.models.user import User
from app.repositories.user_repository import get_by_id
from app.routers.errors import build_error_detail
from app.services.auth.jwt_service import ALGORITHM

bearer_scheme = HTTPBearer(auto_error=False)


def _invalid_token_exception() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=build_error_detail(
            code="INVALID_TOKEN",
            message="Invalid or missing access token.",
        ),
    )


def _token_expired_exception() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=build_error_detail(
            code="TOKEN_EXPIRED",
            message="Access token has expired.",
        ),
    )


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    session: Annotated[AsyncSession, Depends(get_async_session)],
) -> User:
    if credentials is None or not credentials.credentials:
        raise _invalid_token_exception()

    settings = get_settings()

    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.jwt_secret_key,
            algorithms=[ALGORITHM],
        )
    except ExpiredSignatureError as exc:
        raise _token_expired_exception() from exc
    except JWTError as exc:
        raise _invalid_token_exception() from exc

    token_type = payload.get("type")
    subject = payload.get("sub")
    issued_at = payload.get("iat")

    if token_type != "access":
        raise _invalid_token_exception()

    try:
        user_id = UUID(str(subject))
    except (TypeError, ValueError) as exc:
        raise _invalid_token_exception() from exc

    if not isinstance(issued_at, int):
        raise _invalid_token_exception()

    user = await get_by_id(session, user_id)
    if user is None:
        raise _invalid_token_exception()

    if issued_at <= user.token_invalid_before:
        raise _invalid_token_exception()

    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
