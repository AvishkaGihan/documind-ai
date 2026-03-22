from datetime import UTC, datetime
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from fastapi import BackgroundTasks
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.user import User
from app.repositories.user_repository import create_user, get_by_email, get_by_id
from app.schemas.auth import LoginResponse, SignUpResponse, TokenPair, UserPublic
from app.services.auth.jwt_service import (
    create_access_token,
    create_password_reset_token,
    create_refresh_token,
    decode_password_reset_token,
)
from app.services.auth.password_hasher import hash_password, verify_password
from app.services.email_service import send_password_reset_email


class EmailAlreadyExistsError(Exception):
    """Raised when signup is requested for an email that already exists."""


class InvalidCredentialsError(Exception):
    """Raised when login credentials are invalid."""


class InvalidResetTokenError(Exception):
    """Raised when password reset token is invalid or expired."""


class AuthService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def signup(self, email: str, password: str) -> SignUpResponse:
        existing_user = await get_by_email(self._session, email)
        if existing_user is not None:
            raise EmailAlreadyExistsError

        password_hash = hash_password(password)

        try:
            user = await create_user(self._session, email=email, hashed_password=password_hash)
        except IntegrityError as exc:
            await self._session.rollback()
            raise EmailAlreadyExistsError from exc

        subject = str(user.id)
        tokens = TokenPair(
            access_token=create_access_token(subject=subject, email=user.email),
            refresh_token=create_refresh_token(subject=subject, email=user.email),
        )

        return SignUpResponse(
            user=UserPublic(id=user.id, email=user.email),
            tokens=tokens,
        )

    async def login(self, email: str, password: str) -> LoginResponse:
        user = await get_by_email(self._session, email)
        if user is None or not verify_password(password, user.hashed_password):
            raise InvalidCredentialsError

        subject = str(user.id)
        tokens = TokenPair(
            access_token=create_access_token(subject=subject, email=user.email),
            refresh_token=create_refresh_token(subject=subject, email=user.email),
        )

        return LoginResponse(
            user=UserPublic(id=user.id, email=user.email),
            tokens=tokens,
        )

    async def logout(self, user: User) -> None:
        user.token_invalid_before = int(datetime.now(UTC).timestamp())
        await self._session.commit()

    async def request_password_reset(self, email: str, background_tasks: BackgroundTasks) -> None:
        user = await get_by_email(self._session, email)
        if user is None:
            return

        token = create_password_reset_token(subject=str(user.id), email=user.email)
        reset_link = self._build_password_reset_link(token)
        background_tasks.add_task(send_password_reset_email, user.email, reset_link)

    async def confirm_password_reset(self, token: str, new_password: str) -> None:
        try:
            user_id = decode_password_reset_token(token)
        except ValueError as exc:
            raise InvalidResetTokenError from exc

        user = await get_by_id(self._session, user_id)
        if user is None:
            raise InvalidResetTokenError

        user.hashed_password = hash_password(new_password)
        user.token_invalid_before = int(datetime.now(UTC).timestamp())
        await self._session.commit()

    def _build_password_reset_link(self, token: str) -> str:
        settings = get_settings()
        parts = urlsplit(settings.password_reset_frontend_url)
        query = dict(parse_qsl(parts.query, keep_blank_values=True))
        query["token"] = token
        return urlunsplit(
            (parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment)
        )
