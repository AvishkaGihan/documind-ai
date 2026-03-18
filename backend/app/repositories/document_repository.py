from uuid import UUID

from sqlalchemy import select
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


async def get_document_by_id(
    session: AsyncSession,
    *,
    document_id: UUID,
) -> Document | None:
    result = await session.execute(select(Document).where(Document.id == document_id))
    return result.scalar_one_or_none()


async def update_document_status(
    session: AsyncSession,
    *,
    document_id: UUID,
    status: DocumentStatus,
    error_message: str | None = None,
) -> Document:
    document = await get_document_by_id(session, document_id=document_id)
    if document is None:
        raise ValueError(f"Document not found: {document_id}")

    document.status = status
    document.error_message = error_message
    await session.commit()
    await session.refresh(document)
    return document


async def update_document_page_count(
    session: AsyncSession,
    *,
    document_id: UUID,
    page_count: int,
) -> Document:
    document = await get_document_by_id(session, document_id=document_id)
    if document is None:
        raise ValueError(f"Document not found: {document_id}")

    document.page_count = page_count
    await session.commit()
    await session.refresh(document)
    return document
