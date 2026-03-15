# Story 1.4: Set Up Database Models and Alembic Migrations

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want to define the SQLAlchemy data models and configure Alembic migrations,
so that the database schema is version-controlled and ready for feature development.

## Acceptance Criteria

1. **Given** the FastAPI backend project is initialized
   **When** I create the database models and migration setup
   **Then** `backend/app/database.py` configures SQLAlchemy async engine and session factory (supporting SQLite for dev, PostgreSQL for prod)

2. **Given** the database schema requires users
   **When** I define the user model
   **Then** `backend/app/models/user.py` defines a User model with:
   - `id` (UUID)
   - `email` (unique)
   - `hashed_password`
   - `created_at`
   - `updated_at`

3. **Given** the database schema requires documents
   **When** I define the document model
   **Then** `backend/app/models/document.py` defines a Document model with:
   - `id` (UUID)
   - `user_id` (FK)
   - `title`
   - `file_path`
   - `file_size`
   - `page_count`
   - `status` (enum: `processing`, `extracting`, `chunking`, `embedding`, `ready`, `error`)
   - `created_at`
   - `updated_at`

4. **Given** the database schema requires conversations
   **When** I define the conversation model
   **Then** `backend/app/models/conversation.py` defines a Conversation model with:
   - `id` (UUID)
   - `document_id` (FK)
   - `user_id` (FK)
   - `created_at`
   - `updated_at`

5. **Given** the database schema requires messages
   **When** I define the message model
   **Then** `backend/app/models/message.py` defines a Message model with:
   - `id` (UUID)
   - `conversation_id` (FK)
   - `role` (enum: `user`, `assistant`)
   - `content`
   - `citations` (JSON)
   - `created_at`

6. **Given** migrations must be version-controlled
   **When** I configure Alembic
   **Then** `backend/alembic.ini` and `backend/alembic/env.py` are configured for async SQLAlchemy

7. **Given** models are defined and Alembic is configured
   **When** I generate and apply the first migration
   **Then** an initial migration is generated and applies successfully creating all tables

8. **Given** the schema must follow naming conventions
   **When** I name database tables
   **Then** all table names follow `snake_case`, plural convention (`users`, `documents`, `conversations`, `messages`)

## Tasks / Subtasks

- [x] Implement SQLAlchemy async database module (AC: 1)
  - [x] Create `backend/app/database.py` with:
    - [x] `engine` created via `create_async_engine(settings.database_url, ...)`
    - [x] `async_sessionmaker` factory
    - [x] `Base` declarative base + importable `metadata` for Alembic `target_metadata`
  - [x] Ensure dev SQLite works with async driver (`sqlite+aiosqlite://...`) and prod PostgreSQL works with asyncpg (`postgresql+asyncpg://...`)

- [x] Implement models (AC: 2-5, 8)
  - [x] Create `backend/app/models/__init__.py` that exports `Base` (or imports models for Alembic discovery)
  - [x] Create `backend/app/models/user.py` (users)
  - [x] Create `backend/app/models/document.py` (documents)
  - [x] Create `backend/app/models/conversation.py` (conversations)
  - [x] Create `backend/app/models/message.py` (messages)
  - [x] Use SQLAlchemy 2.0 typing (`Mapped[...]`, `mapped_column(...)`) and `select()` style only
  - [x] Use UUID primary keys consistently (UUID4)
  - [x] Ensure `created_at`/`updated_at` are stored as UTC timestamps (and `updated_at` auto-updates)
  - [x] Ensure FK relationships match the story models (document.user_id, conversation.document_id + conversation.user_id, message.conversation_id)

- [x] Configure Alembic for async SQLAlchemy (AC: 6-7)
  - [x] Create `backend/alembic.ini`
  - [x] Create `backend/alembic/env.py` using async migration pattern (`async_engine_from_config` + `run_sync`)
  - [x] Ensure Alembic loads the DB URL from settings (`app.config.get_settings().database_url`) and sets `target_metadata` to your `Base.metadata`
  - [x] Create `backend/alembic/versions/` and generate the initial revision from models

- [x] Verification gates (AC: 7)
  - [x] Run `alembic revision --autogenerate -m "initial schema"` (or equivalent) from `backend/`
  - [x] Run `alembic upgrade head` against SQLite dev DB and confirm all tables exist
  - [x] Document the exact commands + expected outputs in `backend/README.md` (minimal)

## Dev Notes

### Core constraints (non-negotiable)

- **Async-first backend:** Use SQLAlchemy 2.0 async patterns (`create_async_engine`, `AsyncSession`, `async_sessionmaker`).
- **SQLAlchemy 2.0 style only:** No `session.query()`; use `select()`.
- **Pydantic v2 settings source of truth:** Use `backend/app/config.py` and `get_settings()` for `DATABASE_URL`.
- **Naming convention:** Explicitly set `__tablename__` on every model to **plural** snake_case names.
- **Timezone:** All timestamps should be UTC (aligns with project-context rules).

### Current repo state (important for avoiding wrong assumptions)

- `backend/app/config.py` currently defaults `DATABASE_URL` to `sqlite+aiosqlite:///./documind.db`.
  - That implies the backend must have `aiosqlite` available at runtime for dev SQLite.
  - If it is not already installed as a transitive dependency, add `aiosqlite` explicitly to `backend/requirements.txt` (recommended).
- `backend/app/models/` currently exists but is empty.
- `backend/alembic.ini` and `backend/alembic/` do not exist yet.

### Suggested implementation approach (keeps Alembic + async sane)

- Put `Base` and `engine/session` construction in `backend/app/database.py`.
- Ensure Alembic imports your models so `autogenerate` sees them:
  - Common pattern: in `backend/app/models/__init__.py`, import model modules; or in `alembic/env.py`, import them before setting `target_metadata`.
- `citations` column:
  - Use SQLAlchemy `JSON` type. In SQLite it will be stored as TEXT; that’s acceptable for MVP.
- Enums:
  - Define Python enums for `DocumentStatus` and `MessageRole` and map via SQLAlchemy `Enum(...)`.

### Testing expectations (keep it lightweight but verifiable)

- At minimum, provide a repeatable local verification flow (commands under Tasks).
- Optional but valuable: add a small unit test that imports models and asserts `Base.metadata.tables` contains expected plural table names.

### References

- Story requirements + AC: `_bmad-output/planning-artifacts/epics.md` → Epic 1 → Story 1.4
- Required backend directory structure (includes Alembic files): `_bmad-output/planning-artifacts/architecture.md` → Project Structure & Boundaries → Complete Project Directory Structure
- DB + migrations decisions: `_bmad-output/planning-artifacts/architecture.md` → Data Architecture → Migration Approach
- Project-wide rules (SQLAlchemy 2.0 style, async, UTC timestamps): `_bmad-output/project-context.md` → Critical Implementation Rules
- Existing backend settings (DATABASE_URL): `backend/app/config.py`

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Debug Log References

- Story selected from `_bmad-output/implementation-artifacts/sprint-status.yaml`: `1-4-set-up-database-models-and-alembic-migrations` (first `ready-for-dev` in top-to-bottom order).
- RED phase complete: added `backend/tests/unit/test_database_models.py` and observed expected failures for missing database/models/Alembic files.
- GREEN phase complete: implemented async SQLAlchemy database module, models, Alembic async configuration, initial migration generation, and successful upgrade.
- Verification run: SQLite database contains `users`, `documents`, `conversations`, `messages`, and `alembic_version` after `alembic upgrade head`.
- Final quality gates: `pytest` (8 passed) and `ruff check .` (all checks passed).

### Completion Notes List

- Implemented `backend/app/database.py` with `create_async_engine`, `async_sessionmaker`, shared `Base`, exportable `metadata`, and async session dependency generator.
- Added SQLAlchemy 2.0 models for `users`, `documents`, `conversations`, and `messages` using UUID PKs, required FKs, UTC timestamps, and enum-backed status/role fields.
- Added async Alembic setup (`backend/alembic.ini`, `backend/alembic/env.py`, `backend/alembic/script.py.mako`) and generated initial migration revision `827aa99aa683_initial_schema.py`.
- Verified migrations with `python -m alembic revision --autogenerate -m "initial schema"` and `python -m alembic upgrade head`.
- Added explicit `aiosqlite` dependency to support async SQLite development URL defaults.
- Added migration verification/documentation section to `backend/README.md`.
- Added focused unit coverage in `backend/tests/unit/test_database_models.py` for async DB wiring, metadata registration, enum/citations columns, and Alembic async file contract.
- Review Fixes: Applied `ruff` autoformatting and linting fixes to generated Alembic migration file `0db104fe82c5_initial_schema.py`.

### File List

- backend/app/database.py
- backend/app/models/__init__.py
- backend/app/models/user.py
- backend/app/models/document.py
- backend/app/models/conversation.py
- backend/app/models/message.py
- backend/alembic.ini
- backend/alembic/env.py
- backend/alembic/script.py.mako
- backend/alembic/versions/0db104fe82c5_initial_schema.py
- backend/tests/unit/test_database_models.py
- backend/requirements.txt
- backend/README.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/1-4-set-up-database-models-and-alembic-migrations.md

### Change Log

- 2026-03-15: Implemented Story 1.4 database foundation (async SQLAlchemy models + async Alembic migration scaffolding), generated/applied initial schema migration, added validation tests, and updated backend migration docs.
