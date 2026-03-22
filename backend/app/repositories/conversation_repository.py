from collections.abc import Sequence
from datetime import UTC, datetime
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


async def get_latest_conversation_for_document(
    session: AsyncSession,
    *,
    user_id: UUID,
    document_id: UUID,
) -> Conversation | None:
    result = await session.execute(
        select(Conversation)
        .where(
            Conversation.user_id == user_id,
            Conversation.document_id == document_id,
        )
        .order_by(Conversation.updated_at.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def create_conversation(
    session: AsyncSession,
    *,
    user_id: UUID,
    document_id: UUID,
) -> Conversation:
    conversation = Conversation(user_id=user_id, document_id=document_id)
    session.add(conversation)
    await session.flush()
    return conversation


async def get_conversation_for_scope(
    session: AsyncSession,
    *,
    user_id: UUID,
    document_id: UUID,
    conversation_id: UUID,
) -> Conversation | None:
    result = await session.execute(
        select(Conversation).where(
            Conversation.id == conversation_id,
            Conversation.user_id == user_id,
            Conversation.document_id == document_id,
        )
    )
    return result.scalar_one_or_none()


async def touch_conversation(
    session: AsyncSession,
    *,
    conversation_id: UUID,
) -> None:
    conversation = await session.get(Conversation, conversation_id)
    if conversation is not None:
        conversation.updated_at = datetime.now(UTC)
        await session.flush()


async def list_conversations_for_scope(
    session: AsyncSession,
    *,
    user_id: UUID,
    document_id: UUID,
) -> list[Conversation]:
    result = await session.execute(
        select(Conversation)
        .where(
            Conversation.user_id == user_id,
            Conversation.document_id == document_id,
        )
        .order_by(Conversation.updated_at.desc(), Conversation.id.desc())
    )
    return list(result.scalars().all())


async def activate_conversation_for_scope(
    session: AsyncSession,
    *,
    user_id: UUID,
    document_id: UUID,
    conversation_id: UUID,
) -> Conversation | None:
    conversation = await get_conversation_for_scope(
        session,
        user_id=user_id,
        document_id=document_id,
        conversation_id=conversation_id,
    )
    if conversation is None:
        return None

    await touch_conversation(session, conversation_id=conversation.id)
    return conversation
