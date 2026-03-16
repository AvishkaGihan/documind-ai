# Story 2.2: User Login API Endpoint

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a registered user,
I want to log in with my email and password,
so that I can access my documents and conversations securely.

## Acceptance Criteria

1. **Given** I am a registered user with valid credentials
   **When** I send a POST request to `/api/v1/auth/login` with correct email and password
   **Then** a JWT access token (24-hour expiry) and refresh token (7-day expiry) are returned
   **And** the response includes user id and email

2. **Given** I provide incorrect credentials
   **When** I send a POST request to `/api/v1/auth/login`
   **Then** a 401 Unauthorized error is returned with `detail.code: "INVALID_CREDENTIALS"`

## Tasks / Subtasks

- [x] Add login request/response schemas (AC: 1–2)
  - [x] Update `backend/app/schemas/auth.py` with Pydantic v2 models:
    - [x] `LoginRequest { email: EmailStr, password: str }`
      - Use `EmailStr` for email validation.
      - Recommended: enforce `Field(min_length=12)` for password to match signup constraints and to keep standardized 422 validation behavior.
    - [x] `LoginResponse { user: UserPublic, tokens: TokenPair }`
      - Reuse existing `UserPublic` and `TokenPair` models (do not duplicate types).

- [x] Implement login service orchestration (AC: 1–2)
  - [x] Update `backend/app/services/auth_service.py`:
    - [x] Add `InvalidCredentialsError(Exception)` (new) for login failures.
    - [x] Add `async def login(self, email: str, password: str) -> LoginResponse`.
    - [x] Lookup user via `get_by_email(self._session, email)`.
    - [x] Verify password using `verify_password(password, user.hashed_password)` from `backend/app/services/auth/password_hasher.py`.
    - [x] On user-not-found OR password mismatch: raise `InvalidCredentialsError` (do not leak which part failed).
    - [x] On success: issue tokens via existing `create_access_token` / `create_refresh_token` from `backend/app/services/auth/jwt_service.py`.
      - Keep JWT claims and token creation consistent with signup (subject = `str(user.id)`, include `email` in token payload as currently implemented).

- [x] Add login router endpoint (AC: 1–2)
  - [x] Update `backend/app/routers/auth.py`:
    - [x] Add `POST /login` under `/api/v1/auth` with `response_model=LoginResponse`.
    - [x] Status code: `200 OK`.
    - [x] Catch `InvalidCredentialsError` and return `401 Unauthorized` with standardized error payload:
      - `detail.code = "INVALID_CREDENTIALS"`
      - Use `build_error_detail(...)` from `backend/app/routers/errors.py`.
      - Use a generic message like "Invalid email or password." and `field: null`.

- [x] Ensure standardized error formatting is preserved (AC: 2)
  - [x] Do not introduce ad-hoc error dicts.
  - [x] Keep using the existing global `RequestValidationError` handler in `backend/app/main.py` for 422 payload normalization.

- [x] Add tests (AC: 1–2)
  - [x] Create `backend/tests/integration/test_auth_login.py` (or extend auth integration tests if preferred) covering:
    - [x] Login success after signup: returns `200`, includes `user.id`, `user.email`, `tokens.access_token`, `tokens.refresh_token`, `tokens.token_type == "bearer"`.
    - [x] Wrong password returns `401` and exact standardized payload with `detail.code == "INVALID_CREDENTIALS"`.
    - [x] Unknown email also returns `401` and the same standardized payload (no account enumeration).
    - [x] (If password min_length validation is implemented) short password yields `422` with `detail.code == "VALIDATION_ERROR"` and `detail.field == "password"`.

## Dev Notes

### What already exists (reuse; do not reinvent)

- Router + prefixing:
  - Auth router is already mounted at `/api/v1/auth` in `backend/app/main.py`.
  - Signup endpoint already exists in `backend/app/routers/auth.py`.
- Error payload helper:
  - Use `build_error_detail()` from `backend/app/routers/errors.py`.
  - Request validation errors are already normalized via the exception handler in `backend/app/main.py`.
- Security primitives:
  - Password hashing + verification: `backend/app/services/auth/password_hasher.py` (`hash_password`, `verify_password`).
  - JWT issuance: `backend/app/services/auth/jwt_service.py` (`create_access_token`, `create_refresh_token`).
- Data access:
  - User lookups: `backend/app/repositories/user_repository.py` (`get_by_email`).

### API contract guidance (be explicit and consistent)

- Endpoint: `POST /api/v1/auth/login`.
- Response shape should match signup for client simplicity:
  - `user: { id, email }`
  - `tokens: { access_token, refresh_token, token_type }`
- Authentication errors must not reveal whether the email exists.

### Testing + fixtures guidance

- Follow the existing integration testing pattern in `backend/tests/conftest.py`:
  - Dependency override for `get_async_session`.
  - SQLite `aiosqlite` test DB with `Base.metadata.create_all`.
- Prefer creating a user via `POST /api/v1/auth/signup` within the test before attempting login (tests auth flow end-to-end).

### Out of scope (do not implement here)

- JWT authentication middleware (Story 2.3)
- Logout endpoint (Story 2.3)
- Password reset flows (Story 2.4)
- Any Flutter UI changes (Story 2.5)

### References

- Planning: `_bmad-output/planning-artifacts/epics.md` → “Story 2.2: User Login API Endpoint”
- Architecture: `_bmad-output/planning-artifacts/architecture.md` → “Authentication & Security”, “Error Handling Standards”, “API Naming Conventions”
- Project rules: `_bmad-output/project-context.md` → “Authentication Rules”, “API Response Formats”, “Testing Rules”
- Previous story learnings: `_bmad-output/implementation-artifacts/2-1-user-registration-api-endpoint.md`

## Dev Agent Record

### Agent Model Used

GPT-5.2 (GitHub Copilot)

### Debug Log References

- Red phase: `/home/avishkagihan/Documents/documind-ai/backend/.venv/bin/python -m pytest tests/integration/test_auth_login.py -q` -> 4 failed (expected, route missing)
- Green phase: `/home/avishkagihan/Documents/documind-ai/backend/.venv/bin/python -m pytest tests/integration/test_auth_login.py -q` -> 4 passed
- Regression validation: `/home/avishkagihan/Documents/documind-ai/backend/.venv/bin/python -m pytest -q` -> 17 passed
- Lint validation: `/home/avishkagihan/Documents/documind-ai/backend/.venv/bin/python -m ruff check .` -> all checks passed

### Completion Notes List

- Implemented `POST /api/v1/auth/login` with `LoginRequest`/`LoginResponse` models reusing `UserPublic` and `TokenPair`.
- Added `InvalidCredentialsError` and `AuthService.login(...)` to validate credentials without account enumeration and issue access/refresh JWT tokens aligned with signup claims.
- Preserved standardized error formatting by using `build_error_detail(...)` for `401 INVALID_CREDENTIALS` and existing global validation handler for `422 VALIDATION_ERROR`.
- Added integration tests for successful login, wrong password, unknown email, and short-password validation behavior.

### File List

- backend/app/schemas/auth.py
- backend/app/services/auth_service.py
- backend/app/routers/auth.py
- backend/tests/integration/test_auth_login.py

## Change Log

- 2026-03-16: Implemented Story 2.2 login endpoint with service orchestration, schema updates, and integration tests; all backend tests and lint checks passing.
