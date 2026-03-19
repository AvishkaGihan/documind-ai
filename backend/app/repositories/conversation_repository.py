from collections.abc import Sequence
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.conversation import Conversation
from app.models.message import Message


async def list_conversation_ids_for_document(
    session: AsyncSession,
    *,
    document_id: UUID,
) -> list[UUID]:
    result = await session.execute(
        select(Conversation.id).where(Conversation.document_id == document_id)
    )
    return list(result.scalars().all())


async def delete_messages_for_conversation_ids(
    session: AsyncSession,
    *,
    conversation_ids: Sequence[UUID],
) -> int:
    if not conversation_ids:
        return 0

    result = await session.execute(
        delete(Message).where(Message.conversation_id.in_(conversation_ids))
    )
    return int(result.rowcount or 0)


async def delete_conversations_for_document(
    session: AsyncSession,
    *,
    document_id: UUID,
) -> int:
    result = await session.execute(
        delete(Conversation).where(Conversation.document_id == document_id)
    )
    return int(result.rowcount or 0)
