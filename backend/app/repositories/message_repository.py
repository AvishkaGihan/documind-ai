from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.conversation import Conversation
from app.models.message import Message, MessageRole


async def create_message(
    session: AsyncSession,
    *,
    conversation_id: UUID,
    role: MessageRole,
    content: str,
    citations: list[dict[str, object]],
) -> Message:
    message = Message(
        conversation_id=conversation_id,
        role=role,
        content=content,
        citations=citations,
    )
    session.add(message)
    await session.flush()
    return message


async def list_messages_by_conversation(
    session: AsyncSession,
    *,
    conversation_id: UUID,
    limit: int | None = None,
) -> list[Message]:
    statement = select(Message).where(Message.conversation_id == conversation_id)
    if limit is not None and limit > 0:
        result = await session.execute(
            statement.order_by(Message.created_at.desc(), Message.id.desc()).limit(limit)
        )
        messages = list(result.scalars().all())
        return list(reversed(messages))

    result = await session.execute(statement.order_by(Message.created_at.asc(), Message.id.asc()))
    return list(result.scalars().all())


async def list_messages_for_conversation_scope(
    session: AsyncSession,
    *,
    user_id: UUID,
    document_id: UUID,
    conversation_id: UUID,
) -> list[Message]:
    result = await session.execute(
        select(Message)
        .join(Conversation, Conversation.id == Message.conversation_id)
        .where(
            Conversation.id == conversation_id,
            Conversation.user_id == user_id,
            Conversation.document_id == document_id,
        )
        .order_by(Message.created_at.asc(), Message.id.asc())
    )
    return list(result.scalars().all())
