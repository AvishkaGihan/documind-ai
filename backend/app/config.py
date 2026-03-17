from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    env: str = Field(default="development", alias="ENV")
    api_base_url: str = Field(default="http://localhost:8000", alias="API_BASE_URL")
    database_url: str = Field(default="sqlite+aiosqlite:///./documind.db", alias="DATABASE_URL")
    jwt_secret_key: str = Field(default="replace-with-strong-secret", alias="JWT_SECRET_KEY")
    jwt_access_token_expires_hours: int = Field(default=24, alias="JWT_ACCESS_TOKEN_EXPIRES_HOURS")
    jwt_refresh_token_expires_days: int = Field(default=7, alias="JWT_REFRESH_TOKEN_EXPIRES_DAYS")
    password_reset_token_expires_minutes: int = Field(
        default=30,
        alias="PASSWORD_RESET_TOKEN_EXPIRES_MINUTES",
    )
    password_reset_frontend_url: str = Field(
        default="http://localhost:3000/reset-password",
        alias="PASSWORD_RESET_FRONTEND_URL",
    )
    cors_allowed_origins: list[str] = Field(
        default_factory=lambda: [
            "http://localhost:3000",
            "http://localhost:8080",
            "http://localhost:5173",
        ],
        alias="CORS_ALLOWED_ORIGINS",
    )
    groq_api_key: str = Field(default="", alias="GROQ_API_KEY")
    chroma_host: str = Field(default="localhost", alias="CHROMA_HOST")
    chroma_port: int = Field(default=8001, alias="CHROMA_PORT")

    aws_access_key_id: str = Field(default="", alias="AWS_ACCESS_KEY_ID")
    aws_secret_access_key: str = Field(default="", alias="AWS_SECRET_ACCESS_KEY")
    aws_region: str = Field(default="us-east-1", alias="AWS_REGION")
    s3_bucket_name: str = Field(default="", alias="S3_BUCKET_NAME")
    smtp_host: str = Field(default="", alias="SMTP_HOST")
    smtp_port: int = Field(default=587, alias="SMTP_PORT")
    smtp_username: str = Field(default="", alias="SMTP_USERNAME")
    smtp_password: str = Field(default="", alias="SMTP_PASSWORD")
    smtp_from_email: str = Field(default="", alias="SMTP_FROM_EMAIL")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
        populate_by_name=True,
        enable_decoding=False,
    )

    @field_validator("cors_allowed_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, value: str | list[str]) -> list[str]:
        if isinstance(value, list):
            return value
        if not value:
            return []
        return [origin.strip() for origin in value.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
