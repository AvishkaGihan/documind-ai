from pydantic import BaseModel, Field, field_validator


class AskQuestionRequest(BaseModel):
    question: str = Field(min_length=1, max_length=2000)

    @field_validator("question")
    @classmethod
    def validate_question(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("Question cannot be empty")
        return normalized


class CitationPublic(BaseModel):
    page_number: int = Field(ge=1)
    text: str = Field(min_length=1, max_length=280)


class AskQuestionResponse(BaseModel):
    answer: str
    citations: list[CitationPublic] = Field(default_factory=list)
