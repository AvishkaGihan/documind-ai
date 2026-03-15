# Story 1.1: Initialize Backend Project with FastAPI and Dependencies

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want to initialize the FastAPI backend project with the required folder structure, dependencies, and baseline configuration,
so that all future backend stories can be implemented on a consistent, testable foundation.

## Acceptance Criteria

1. **Given** no backend project exists
   **When** I create the `backend/` directory and initialize the FastAPI project
   **Then** the directory structure matches the architecture specification (`app/`, `app/routers/`, `app/services/`, `app/models/`, `app/schemas/`, `app/repositories/`, `app/middleware/`, `tests/`).

2. **Given** the backend project is initialized
   **When** I define Python dependencies
   **Then** `backend/requirements.txt` contains (at minimum) the specified dependencies:
   - `fastapi[standard]==0.135.1`
   - `uvicorn[standard]`
   - `langchain==1.2.10`
   - `chromadb==1.5.5`
   - `sentence-transformers==5.3.0`
   - `python-multipart`
   - `pydantic[email]`
   - `python-jose[cryptography]`
   - `passlib[bcrypt]`
   - `boto3`
   - `aiofiles`
   - `sqlalchemy[asyncio]`
   - `alembic`
   - `asyncpg`
   - `slowapi`
   - `structlog`
   - `pytest`
   - `pytest-asyncio`
   - `httpx`
   - `ruff`

3. **Given** the backend server is started in development
   **When** I run `uvicorn app.main:app --reload --port 8000`
   **Then** the server starts successfully and `/docs` returns Swagger UI.

4. **Given** the backend app is configured
   **When** I run the app
   **Then** `app/main.py` creates a FastAPI application instance with CORS middleware configured.

5. **Given** the backend uses environment configuration
   **When** I configure settings
   **Then** `app/config.py` uses Pydantic v2 `BaseSettings` for typed environment configuration.

6. **Given** environment variables are required
   **When** I document them
   **Then** `backend/.env.example` documents all required environment variables.

## Tasks / Subtasks

- [x] Create backend scaffolding + Python tooling (AC: 1)
   - [x] Create `backend/` directory with `requirements.txt`, `README.md`, and `.env.example`
   - [x] Create `backend/app/` package with `__init__.py`
   - [x] Create baseline folder structure:
    - `backend/app/routers/`, `backend/app/services/`, `backend/app/models/`, `backend/app/schemas/`, `backend/app/repositories/`, `backend/app/middleware/`
    - `backend/tests/` (plus `backend/tests/unit/`, `backend/tests/integration/`, `backend/tests/fixtures/`) matching architecture guidance

- [x] Pin and install backend dependencies (AC: 2)
   - [x] Populate `backend/requirements.txt` with the exact pinned versions listed in AC
   - [x] (Optional but recommended) Add `backend/pyproject.toml` for tool config (ruff, pytest) if the repo standardizes on it

- [x] Implement FastAPI entrypoint + CORS (AC: 3, 4)
   - [x] Create `backend/app/main.py` with a FastAPI `app` instance
   - [x] Add CORS middleware in a minimal, safe default configuration for local dev (document expected origins)

- [x] Implement typed settings (Pydantic v2) (AC: 5, 6)
   - [x] Create `backend/app/config.py` using `pydantic_settings.BaseSettings` (Pydantic v2) and `.env` loading
    - [x] Define core settings keys expected by future stories (database URL, JWT secret, storage provider config, Groq key)
   - [x] Document all keys in `backend/.env.example` with clear placeholders

- [x] Baseline test + lint wiring (supports AC: 3)
   - [x] Add minimal pytest scaffolding (`backend/tests/conftest.py`) so later stories can add tests without restructuring
   - [x] Ensure `ruff` is configured to run against `backend/` (via default config or `pyproject.toml`)

## Dev Notes

### Must-follow architecture and conventions

- **Project structure is not negotiable:** follow the directory tree under `backend/` exactly as specified in the architecture document (routers → services → repositories layering, with `middleware/`, `schemas/`, and `tests/`).
- **Pydantic v2 only:** use Pydantic v2 syntax and `BaseSettings` for typed settings.
- **Async-first backend:** default to `async def` for route handlers/services and use SQLAlchemy 2.0 async patterns in later stories.
- **Keep routers thin:** routers handle HTTP concerns only; business logic belongs in services; DB access belongs in repositories.

### Dependency guardrails (prevent wrong libs / version drift)

- Do **not** “upgrade to latest” versions while implementing this story.
- Use the exact versions pinned in the epic acceptance criteria for: FastAPI, LangChain, ChromaDB, Sentence Transformers.
- Include `ruff`, `pytest`, `pytest-asyncio`, and `httpx` from day one so subsequent stories can add tests and lint checks without churn.

### Minimal CORS guidance (avoid insecure defaults)

- Configure CORS intentionally for local development; document expected origins for mobile dev.
- Avoid permissive `allow_origins=["*"]` in production defaults.

### Environment variables to document in `.env.example` (AC: 6)

- `ENV` (e.g. `development`)
- `API_BASE_URL` (if used by backend-generated links)
- `DATABASE_URL` (SQLite dev / PostgreSQL prod)
- `JWT_SECRET_KEY`
- `JWT_ACCESS_TOKEN_EXPIRES_HOURS` (default 24)
- `JWT_REFRESH_TOKEN_EXPIRES_DAYS` (default 7)
- `CORS_ALLOWED_ORIGINS` (comma-separated)
- `GROQ_API_KEY`
- Storage (choose one approach and document it):
   - S3: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `S3_BUCKET_NAME`
   - Cloudinary: `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`
- ChromaDB (if running client-server later): `CHROMA_HOST`, `CHROMA_PORT`

### References

- Story requirements and dependency list: `_bmad-output/planning-artifacts/epics.md` → "Epic 1" → "Story 1.1: Initialize Backend Project with FastAPI and Dependencies"
- Backend project structure blueprint: `_bmad-output/planning-artifacts/architecture.md` → "Project Structure & Boundaries" → "Complete Project Directory Structure"
- Backend stack + implementation rules: `_bmad-output/project-context.md` → "Technology Stack & Versions" and "Critical Implementation Rules"
- API patterns (for future stories): `_bmad-output/planning-artifacts/architecture.md` → "API & Communication Patterns" and "Implementation Patterns & Consistency Rules"

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Debug Log References

- Created backend scaffold and baseline package/test structure under `backend/`.
- Implemented tests first for `app.main` and `app.config`, confirmed initial failure due missing modules.
- Resolved a `pydantic-settings` parsing issue for comma-separated CORS origins by setting `enable_decoding=False` and validating with a field validator.
- Completed full `pip install -r requirements.txt` after retrying with higher pip retries/timeouts due transient network reset during large package downloads.

### Implementation Plan

- Scaffold backend folders and baseline tooling files from story requirements.
- Add failing tests for startup/docs/CORS and typed settings loading.
- Implement minimal FastAPI app + CORS and typed settings with `.env` loading.
- Wire pytest and ruff configuration, then run tests/lint and runtime docs verification.

### Completion Notes List

- Implemented complete backend scaffold matching the architecture-required folders and test layout.
- Added pinned dependency manifest in `backend/requirements.txt` and optional tool config in `backend/pyproject.toml`.
- Added `backend/app/main.py` with FastAPI app instance and explicit local-dev CORS configuration sourced from settings.
- Added `backend/app/config.py` using Pydantic v2 `pydantic_settings.BaseSettings` with typed fields and `.env` support.
- Documented required environment variables in `backend/.env.example` including JWT, DB, CORS, storage, and Chroma keys.
- Added baseline tests (`tests/unit/test_config.py`, `tests/integration/test_main.py`) and pytest scaffolding (`tests/conftest.py`).
- Validation results:
   - `.venv/bin/pytest` -> 3 passed
   - `.venv/bin/ruff check .` -> all checks passed
   - Runtime check: `uvicorn app.main:app --port 8000` + probe `/docs` -> HTTP 200

### File List

- backend/README.md
- backend/requirements.txt
- backend/.env.example
- backend/pyproject.toml
- backend/app/__init__.py
- backend/app/main.py
- backend/app/config.py
- backend/tests/conftest.py
- backend/tests/integration/test_main.py
- backend/tests/unit/test_config.py

## Change Log

- 2026-03-15: Implemented Story 1.1 backend foundation (scaffold, dependencies, FastAPI entrypoint, typed settings, env documentation, tests, and lint/test validation).
