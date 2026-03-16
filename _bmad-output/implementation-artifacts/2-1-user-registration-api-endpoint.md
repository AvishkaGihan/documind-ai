# Story 2.1: User Registration API Endpoint

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a new user,
I want to create an account using my email and password,
so that I have a personal, secure space for my documents and conversations.

## Acceptance Criteria

1. **Given** I am a new user without an account
   **When** I send a POST request to `/api/v1/auth/signup` with a valid email and password (≥12 characters)
   **Then** a new user record is created with the password hashed using bcrypt
   **And** a JWT access token (24-hour expiry) and refresh token (7-day expiry) are returned
   **And** the response includes user id and email

2. **Given** I provide an email that is already registered
   **When** I send a POST request to `/api/v1/auth/signup`
   **Then** a `409 Conflict` error is returned with `detail.code: "EMAIL_ALREADY_EXISTS"`

3. **Given** I provide a password shorter than 12 characters
   **When** I send a POST request to `/api/v1/auth/signup`
   **Then** a `422 Unprocessable Entity` error is returned with `detail.code: "VALIDATION_ERROR"` and `detail.field: "password"`

## Tasks / Subtasks

- [x] Add auth request/response schemas (AC: 1–3)
  - [x] Create `app/schemas/auth.py` (or similar) with Pydantic v2 models:
    - [x] `SignUpRequest { email: EmailStr, password: str }` with password length validation (≥12)
    - [x] `UserPublic { id: UUID4, email: EmailStr }`
    - [x] `TokenPair { access_token: str, refresh_token: str, token_type: "bearer" }`
    - [x] `SignUpResponse { user: UserPublic, tokens: TokenPair }` (include id+email as required)

- [x] Add user repository for email lookups + creation (AC: 1–2)
  - [x] Create `app/repositories/user_repository.py`
  - [x] Implement `get_by_email(session, email) -> User | None`
  - [x] Implement `create_user(session, email, hashed_password) -> User`
  - [x] Ensure SQLAlchemy 2.0 async patterns only (`select()`, `await session.execute`, `await session.commit`)

- [x] Add password hashing + JWT issuance utilities (AC: 1)
  - [x] Create `app/services/auth/password_hasher.py` (or `app/services/security/passwords.py`) using `passlib[bcrypt]`
  - [x] Create `app/services/auth/jwt_service.py` using `python-jose[cryptography]`
  - [x] Use settings from `app/config.py`:
    - [x] `JWT_SECRET_KEY`
    - [x] `JWT_ACCESS_TOKEN_EXPIRES_HOURS` (default 24)
    - [x] `JWT_REFRESH_TOKEN_EXPIRES_DAYS` (default 7)

- [x] Implement signup service orchestration (AC: 1–2)
  - [x] Create `app/services/auth_service.py` with `signup(email, password)`
  - [x] Validate pre-existence (email already registered) and raise a typed domain error used by the router
  - [x] Hash password, create user, issue tokens

- [x] Add auth router endpoint (AC: 1–3)
  - [x] Create `app/routers/auth.py` with `POST /signup`
  - [x] Mount under `/api/v1/auth` in `app/main.py`
  - [x] Ensure router contains HTTP-only logic (parse, call service, return response)

- [x] Standardize error response formatting (AC: 2–3)
  - [x] If not already present, add a small error helper to ensure errors match:
    - [x] `{"detail": {"code": "...", "message": "...", "field": null}}`
  - [x] For duplicate email: `409` with code `EMAIL_ALREADY_EXISTS`
  - [x] For password validation: `422` with code `VALIDATION_ERROR` and field `password`

- [x] Add tests (AC: 1–3)
  - [x] Add integration tests under `tests/integration/` for `/api/v1/auth/signup`:
    - [x] success returns 200/201, contains `user.id`, `user.email`, `tokens.access_token`, `tokens.refresh_token`
    - [x] duplicate email returns 409 and correct `detail.code`
    - [x] short password returns 422 and correct `detail.code` + `detail.field`
  - [x] Ensure tests use the project’s async DB session pattern (SQLite dev) and do not rely on global mutable state

## Dev Notes

### What already exists (reuse; do not reinvent)

- ORM model: `app/models/user.py` defines `users` table with `email` unique + indexed.
- Settings: `app/config.py` already includes JWT expiry settings and `JWT_SECRET_KEY` (aliases).
- Async DB session dependency: `app/database.py` exposes `get_async_session()`.
- Dependencies are already installed in `backend/requirements.txt` (including `python-jose[cryptography]`, `passlib[bcrypt]`, `pydantic-settings`).

### API contract guidance (be explicit and consistent)

- Endpoint must be versioned and grouped: `/api/v1/auth/signup`.
- Prefer response model (Pydantic) and return a single JSON object (not a list wrapper).
- Recommend response shape (token-efficient, explicit):
  - `user: { id, email }`
  - `tokens: { access_token, refresh_token, token_type }`

### Validation expectations

- Email validation: use Pydantic `EmailStr`.
- Password validation: enforce min length 12 at schema level so invalid input yields `422`.
- However, acceptance criteria requires the error payload include `detail.code` + `detail.field`.
  - If default FastAPI/Pydantic validation errors don’t match the project’s standard error format, add a custom exception handler to normalize validation errors into the standard format.

### Data integrity and race conditions

- Must prevent duplicates even under concurrency.
- Preferred approach:
  1) Check existence by email
  2) Attempt insert
  3) On `IntegrityError` (unique constraint), translate to `EMAIL_ALREADY_EXISTS` (still `409`)

### Security requirements (must follow)

- Hash passwords with bcrypt via `passlib[bcrypt]`.
- Never return `hashed_password`.
- JWT expiry: access token 24h; refresh token 7d.
- Tokens are used by later stories (2.2 login, 2.3 middleware/logout), so keep JWT claim design stable.
  - Minimal claims: `sub` = user id (UUID string), `email` optional, `type` = `access|refresh`, `exp`.

### Project structure notes

- Backend directories `app/routers/`, `app/services/`, `app/repositories/`, `app/schemas/` currently exist but are empty.
- This story should establish the first concrete pattern for:
  - router → service → repository layering
  - standard error payload shape
  - JWT/password helper modules

### Testing notes

- Existing tests use `fastapi.testclient.TestClient` in `tests/conftest.py`.
- If the signup endpoint needs DB access, add test DB setup fixtures (e.g., SQLite temp DB, run migrations) so tests are isolated and repeatable.

### Out of scope (do not implement here)

- Login endpoint (`/api/v1/auth/login`) — Story 2.2
- JWT auth middleware and logout — Story 2.3
- Password reset — Story 2.4
- Any Flutter UI — Story 2.5

### References

- Planning: `_bmad-output/planning-artifacts/epics.md` → “Story 2.1: User Registration API Endpoint”
- Architecture: `_bmad-output/planning-artifacts/architecture.md` → “Authentication & Security”, “API & Communication Patterns”, “Error Handling Standards”
- Project rules: `_bmad-output/project-context.md` → “Critical Implementation Rules”, “API Response Formats”, “Authentication Rules”

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex (GitHub Copilot)

### Debug Log References

- `python -m pytest tests/integration/test_auth_signup.py -q` (red phase: initial 404 failures)
- `python -m pytest tests/integration/test_auth_signup.py -q` (green phase: 3 passed)
- `python -m pytest -q` (full regression: 13 passed)
- `python -m ruff check .` (lint: all checks passed)

### Completion Notes List

- Implemented full signup flow with schema -> router -> service -> repository layering.
- Added standardized error helper and global request-validation normalization to enforce `detail.code/message/field` contract.
- Added integration tests for success, duplicate email conflict, and short password validation payload.
- Added isolated async SQLite fixtures via dependency override for deterministic endpoint integration tests.
- Added explicit `bcrypt<5` compatibility pin because `passlib 1.7.4` is incompatible with `bcrypt 5.x` on Python 3.14.

### File List

Implemented/updated files:
- `backend/app/main.py`
- `backend/app/routers/auth.py`
- `backend/app/routers/errors.py`
- `backend/app/services/auth_service.py`
- `backend/app/services/auth/__init__.py`
- `backend/app/services/auth/password_hasher.py`
- `backend/app/services/auth/jwt_service.py`
- `backend/app/repositories/user_repository.py`
- `backend/app/schemas/auth.py`
- `backend/tests/conftest.py`
- `backend/tests/integration/test_auth_signup.py`
- `backend/requirements.txt`

### Change Log

- 2026-03-16: Implemented Story 2.1 signup API endpoint and supporting auth layers; added integration coverage and standardized error formatting; all backend tests and lint checks passing.
