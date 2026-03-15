from app.config import Settings


def test_settings_loads_typed_values_from_env(monkeypatch) -> None:
    monkeypatch.setenv("ENV", "development")
    monkeypatch.setenv("DATABASE_URL", "sqlite+aiosqlite:///./test.db")
    monkeypatch.setenv("JWT_SECRET_KEY", "secret")
    monkeypatch.setenv("JWT_ACCESS_TOKEN_EXPIRES_HOURS", "24")
    monkeypatch.setenv("JWT_REFRESH_TOKEN_EXPIRES_DAYS", "7")
    monkeypatch.setenv("CORS_ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8080")
    monkeypatch.setenv("GROQ_API_KEY", "groq-key")

    settings = Settings()

    assert settings.env == "development"
    assert settings.database_url == "sqlite+aiosqlite:///./test.db"
    assert settings.jwt_secret_key == "secret"
    assert settings.jwt_access_token_expires_hours == 24
    assert settings.jwt_refresh_token_expires_days == 7
    assert settings.cors_allowed_origins == ["http://localhost:3000", "http://localhost:8080"]
    assert settings.groq_api_key == "groq-key"
