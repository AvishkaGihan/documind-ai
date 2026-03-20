from __future__ import annotations

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.conversation import Conversation
from app.models.message import Message, MessageRole
from app.repositories.conversation_repository import (
    create_conversation,
    get_conversation_for_scope,
    get_latest_conversation_for_document,
    touch_conversation,
)
from app.repositories.message_repository import (
    create_message,
    list_messages_by_conversation,
    list_messages_for_conversation_scope,
)


class ConversationNotFoundError(Exception):
    """Raised when a conversation cannot be found for the user/document scope."""


class ConversationService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_or_create_latest_conversation(
        self,
        *,
        user_id: UUID,
        document_id: UUID,
    ) -> Conversation:
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
            await self._session.commit()
        return conversation

    async def get_prompt_history(
        self,
        *,
        user_id: UUID,
        document_id: UUID,
        max_messages: int,
    ) -> list[Message]:
        conversation = await get_latest_conversation_for_document(
            self._session,
            user_id=user_id,
            document_id=document_id,
        )
        if conversation is None:
            return []
        return await list_messages_by_conversation(
            self._session,
            conversation_id=conversation.id,
            limit=max_messages,
        )

    async def create_new_conversation(
        self,
        *,
        user_id: UUID,
        document_id: UUID,
    ) -> UUID:
        conversation = await create_conversation(
            self._session,
            user_id=user_id,
            document_id=document_id,
        )
        await self._session.commit()
        return conversation.id

    async def list_messages_for_conversation(
        self,
        *,
        user_id: UUID,
        document_id: UUID,
        conversation_id: UUID,
    ) -> list[Message]:
        messages = await list_messages_for_conversation_scope(
            self._session,
            user_id=user_id,
            document_id=document_id,
            conversation_id=conversation_id,
        )

        if messages:
            return messages

        scoped_conversation = await get_conversation_for_scope(
            self._session,
            user_id=user_id,
            document_id=document_id,
            conversation_id=conversation_id,
        )
        if scoped_conversation is None:
            raise ConversationNotFoundError
        return []

    async def persist_qa_exchange(
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

    async def persist_stream_completion(
        self,
        *,
        user_id: UUID,
        document_id: UUID,
        question: str,
        answer_text: str,
        citations: list[dict[str, object]],
    ) -> UUID:
        return await self.persist_qa_exchange(
            user_id=user_id,
            document_id=document_id,
            question=question,
            answer_text=answer_text,
            citations=citations,
        )
