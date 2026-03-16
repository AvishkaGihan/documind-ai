from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


async def get_by_email(session: AsyncSession, email: str) -> User | None:
    result = await session.execute(select(User).where(User.email == email))
    return result.scalar_one_or_none()


async def create_user(session: AsyncSession, email: str, hashed_password: str) -> User:
    user = User(email=email, hashed_password=hashed_password)
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user
