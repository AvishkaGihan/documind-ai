from collections.abc import AsyncGenerator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.database import Base, get_async_session
from app.main import app


@pytest.fixture
def test_session_factory(tmp_path: Path) -> async_sessionmaker[AsyncSession]:
    test_db_path = tmp_path / "test.db"
    database_url = f"sqlite+aiosqlite:///{test_db_path}"
    engine = create_async_engine(database_url, pool_pre_ping=True)
    session_factory = async_sessionmaker(
        bind=engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async def _prepare_schema() -> None:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)

    async def _dispose_engine() -> None:
        await engine.dispose()

    import asyncio

    asyncio.run(_prepare_schema())
    try:
        yield session_factory
    finally:
        asyncio.run(_dispose_engine())


@pytest.fixture
def client(test_session_factory: async_sessionmaker[AsyncSession]) -> TestClient:
    async def override_get_async_session() -> AsyncGenerator[AsyncSession, None]:
        async with test_session_factory() as session:
            yield session

    app.dependency_overrides[get_async_session] = override_get_async_session
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
