from __future__ import annotations

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.message import MessageRole
from app.repositories.conversation_repository import (
    create_conversation,
    get_latest_conversation_for_document,
    touch_conversation,
)
from app.repositories.message_repository import create_message


class ConversationService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def persist_stream_completion(
        self,
        *,
        user_id: UUID,
        document_id: UUID,
        question: str,
        answer_text: str,
        citations: list[dict[str, object]],
    ) -> UUID:
        conversation = await get_latest_conversation_for_document(
            self._session,
            user_id=user_id,
            document_id=document_id,
        )
        if conversation is None:
            conversation = await create_conversation(
                self._session,
                user_id=user_id,
                document_id=document_id,
            )
        else:
            await touch_conversation(
                self._session,
                conversation_id=conversation.id,
            )

        await create_message(
            self._session,
            conversation_id=conversation.id,
            role=MessageRole.USER,
            content=question,
            citations=[],
        )
        assistant_message = await create_message(
            self._session,
            conversation_id=conversation.id,
            role=MessageRole.ASSISTANT,
            content=answer_text,
            citations=citations,
        )
        await self._session.commit()
        return assistant_message.id
