import importlib
from pathlib import Path

from sqlalchemy import JSON, String
from sqlalchemy import Enum as SAEnum

from app.config import get_settings


def test_async_database_module_exposes_engine_session_and_metadata() -> None:
    database = importlib.import_module("app.database")

    settings = get_settings()

    assert database.engine.url.drivername == "sqlite+aiosqlite"
    assert str(database.engine.url) == settings.database_url
    assert database.async_session_factory is not None
    assert database.Base.metadata is database.metadata


def test_metadata_registers_expected_plural_tables() -> None:
    # Importing app.models should register all ORM tables on Base.metadata.
    importlib.import_module("app.models")
    database = importlib.import_module("app.database")

    expected_table_names = {"users", "documents", "conversations", "messages"}
    assert expected_table_names.issubset(set(database.Base.metadata.tables.keys()))


def test_document_status_enum_values_and_citations_column_type() -> None:
    document_module = importlib.import_module("app.models.document")
    message_module = importlib.import_module("app.models.message")

    status_values = [item.value for item in document_module.DocumentStatus]
    role_values = [item.value for item in message_module.MessageRole]

    assert status_values == ["processing", "extracting", "chunking", "embedding", "ready", "error"]
    assert role_values == ["user", "assistant"]

    citations_column = message_module.Message.__table__.c.citations
    assert isinstance(citations_column.type, JSON)

    error_message_column = document_module.Document.__table__.c.error_message
    assert isinstance(error_message_column.type, String)
    assert error_message_column.nullable is True


def test_enum_columns_are_sqlalchemy_enums() -> None:
    document_module = importlib.import_module("app.models.document")
    message_module = importlib.import_module("app.models.message")

    assert isinstance(document_module.Document.__table__.c.status.type, SAEnum)
    assert isinstance(message_module.Message.__table__.c.role.type, SAEnum)


def test_alembic_files_exist_for_async_migrations() -> None:
    backend_root = Path(__file__).resolve().parents[2]
    alembic_env_path = backend_root / "alembic" / "env.py"
    alembic_ini_path = backend_root / "alembic.ini"

    with alembic_env_path.open(encoding="utf-8") as env_file:
        env_contents = env_file.read()
    with alembic_ini_path.open(encoding="utf-8") as ini_file:
        ini_contents = ini_file.read()

    assert "async_engine_from_config" in env_contents
    assert "target_metadata = Base.metadata" in env_contents
    assert "script_location = alembic" in ini_contents
