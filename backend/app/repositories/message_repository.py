from __future__ import annotations

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

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
