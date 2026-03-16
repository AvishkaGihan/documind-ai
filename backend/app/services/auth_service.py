from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.user_repository import create_user, get_by_email
from app.schemas.auth import LoginResponse, SignUpResponse, TokenPair, UserPublic
from app.services.auth.jwt_service import create_access_token, create_refresh_token
from app.services.auth.password_hasher import hash_password, verify_password


class EmailAlreadyExistsError(Exception):
    """Raised when signup is requested for an email that already exists."""


class InvalidCredentialsError(Exception):
    """Raised when login credentials are invalid."""


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
