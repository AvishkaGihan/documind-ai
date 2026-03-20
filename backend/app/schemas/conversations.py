from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class CreateConversationResponse(BaseModel):
    conversation_id: UUID


class ConversationPublic(BaseModel):
    id: UUID
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ConversationListResponse(BaseModel):
    items: list[ConversationPublic]
    total: int
    page: int
    page_size: int


class ActivateConversationResponse(BaseModel):
    conversation_id: UUID
