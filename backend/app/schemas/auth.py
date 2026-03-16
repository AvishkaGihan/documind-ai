from typing import Literal
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


class SignUpRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=12)


class UserPublic(BaseModel):
    id: UUID
    email: EmailStr


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"


class SignUpResponse(BaseModel):
    user: UserPublic
    tokens: TokenPair


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=12)


class LoginResponse(BaseModel):
    user: UserPublic
    tokens: TokenPair
