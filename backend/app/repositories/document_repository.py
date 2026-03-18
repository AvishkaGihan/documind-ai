from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.document import Document, DocumentStatus


async def create_document(
    session: AsyncSession,
    *,
    user_id: UUID,
    title: str,
    file_path: str,
    file_size: int,
    page_count: int,
    status: DocumentStatus,
) -> Document:
    document = Document(
        user_id=user_id,
        title=title,
        file_path=file_path,
        file_size=file_size,
        page_count=page_count,
        status=status,
    )
    session.add(document)
    await session.commit()
    await session.refresh(document)
    return document
