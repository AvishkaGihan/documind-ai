from uuid import UUID

from pydantic import BaseModel


class CreateConversationResponse(BaseModel):
    conversation_id: UUID
