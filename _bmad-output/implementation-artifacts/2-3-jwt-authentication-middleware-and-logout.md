# Story 2.3: JWT Authentication Middleware and Logout

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a logged-in user,
I want my requests to be authenticated via JWT and be able to log out,
so that my session is secure and I can terminate it when needed.

## Acceptance Criteria

1. **Given** I have a valid JWT access token
   **When** I include it in the `Authorization: Bearer <token>` header on any authenticated endpoint
   **Then** the request is processed with my user context extracted from the token

2. **Given** I have an expired or invalid JWT token
   **When** I make a request to any authenticated endpoint
   **Then** a 401 Unauthorized error is returned with `detail.code: "TOKEN_EXPIRED"` or `"INVALID_TOKEN"`

3. **Given** I am logged in
   **When** I send a POST request to `/api/v1/auth/logout`
   **Then** my current session is invalidated and a 200 success response is returned

## Tasks / Subtasks

- [x] Add JWT decoding + auth dependency (AC: 1–2)
  - [x] Create `backend/app/dependencies/auth.py` (preferred) with:
    - [x] `HTTPBearer(auto_error=False)` (or equivalent) to read `Authorization: Bearer ...`
    - [x] `async def get_current_user(...) -> User` that:
      - [x] Extracts token string from header
      - [x] Decodes token via `python-jose` using the same secret + algorithm as `jwt_service.py`
      - [x] Validates required claims:
        - [x] `sub` exists (UUID string)
        - [x] `type == "access"` (refresh tokens must be rejected)
        - [x] `exp` validated by the JWT library
      - [x] Maps JWT errors to standardized 401 payloads:
        - [x] Expired -> `detail.code = "TOKEN_EXPIRED"`
        - [x] Invalid/malformed/signature/type mismatch -> `detail.code = "INVALID_TOKEN"`
      - [x] Loads the user from DB (by `sub`) using repository call (do not query from router)
      - [x] Returns the `User` instance for downstream use
  - [x] Add `CurrentUser` alias pattern (optional but recommended): `CurrentUser = Annotated[User, Depends(get_current_user)]`

- [x] Add logout endpoint (AC: 3)
  - [x] Update `backend/app/routers/auth.py`:
    - [x] Add `POST /logout` under `/api/v1/auth`
    - [x] Require authentication via `Depends(get_current_user)` (do not accept refresh token)
    - [x] Implement using service layer (no business logic in router)
    - [x] Return a minimal success response (e.g. `{ "status": "ok" }`)

- [x] Implement “session invalidation” semantics (AC: 3)
  - [x] Choose a token revocation strategy that works with stateless JWT and fits MVP simplicity.
  - [x] Recommended MVP approach: **invalidate-by-time**
    - [x] Add a `token_invalid_before` field on `User` (UTC unix seconds, default 0)
    - [x] Add `iat` claim to both access + refresh tokens when issuing (UTC unix seconds)
    - [x] In `get_current_user`, reject tokens where `iat <= user.token_invalid_before` with 401 `INVALID_TOKEN`
    - [x] On logout, set `user.token_invalid_before = now_utc_unix_seconds` and commit
    - [x] Document behavior: logout invalidates *all* tokens issued before logout (covers “current session” and is acceptable for MVP)
  - [x] Alternative (more complex, optional): per-token blacklist using `jti` + `revoked_tokens` table (explicitly deferred for MVP)

- [x] Add required repository/service plumbing (AC: 1–3)
  - [x] Update `backend/app/repositories/user_repository.py`:
    - [x] Add `get_by_id(session, user_id: UUID) -> User | None`
  - [x] Update `backend/app/services/auth_service.py`:
    - [x] Add `async def logout(self, user: User) -> None` implementing the chosen invalidation strategy
    - [x] Keep domain errors and router translation consistent with existing patterns

- [x] Update JWT utilities (AC: 1–3)
  - [x] Update `backend/app/services/auth/jwt_service.py`:
    - [x] Ensure tokens include `iat` claim (UTC unix seconds) alongside existing claims (`sub`, `type`, `exp`, optional `email`)
    - [x] Do not break existing `create_access_token` / `create_refresh_token` call sites

- [x] Update database schema (required if using invalidate-by-time)
  - [x] Update `backend/app/models/user.py` to include `token_invalid_before` column
  - [x] Generate an Alembic revision under `backend/alembic/versions/` to add the new column with a safe default

- [x] Add tests (AC: 1–3)
  - [x] Add `backend/tests/integration/test_auth_logout.py` with coverage:
    - [x] No header -> 401 with standardized `detail.code == "INVALID_TOKEN"`
    - [x] Malformed header/token -> 401 with standardized `detail.code == "INVALID_TOKEN"`
    - [x] Expired token -> 401 with standardized `detail.code == "TOKEN_EXPIRED"` (generate a token with `exp` in the past)
    - [x] Valid access token -> logout returns 200
    - [x] After logout, the *same* access token is rejected (401 `INVALID_TOKEN`) on a subsequent authenticated call

## Dev Notes

### What already exists (reuse; do not reinvent)

- JWT issuance utilities: `backend/app/services/auth/jwt_service.py` (claims today: `sub`, `type`, `exp`, optional `email`).
- Signup + login patterns:
  - Router/service layering established in `backend/app/routers/auth.py` and `backend/app/services/auth_service.py`.
  - Standard error payload builder: `backend/app/routers/errors.py` (`build_error_detail`).
  - Global request validation normalization exists in `backend/app/main.py` (422 -> `VALIDATION_ERROR`).
- Async DB session dependency: `backend/app/database.py` exposes `get_async_session()`.
- User model: `backend/app/models/user.py`.

### Guardrails (avoid regressions)

- Do not protect `/docs`, `/openapi.json`, `/redoc`, or `/health` with JWT.
  - There is an existing integration test asserting `/docs` returns 200.
  - Prefer dependency-based auth on protected endpoints/routers (not a global Starlette middleware that can accidentally block docs).

### Error formatting (must stay consistent)

- All 401 responses from auth dependency must use:
  - `{"detail": {"code": "...", "message": "...", "field": null}}`
- Use `build_error_detail(...)` (no ad-hoc dicts).
- Map:
  - JWT expired -> `TOKEN_EXPIRED`
  - Any other failure (missing token, malformed header, wrong signature, wrong token type, revoked) -> `INVALID_TOKEN`

### Token type rules

- Only `type == "access"` tokens may authenticate requests.
- Refresh tokens are for future refresh flows (not in this story); treat them as `INVALID_TOKEN` if presented to protected endpoints.

### Session invalidation (logout) recommendation

- This repo currently uses stateless JWT; to make “logout” meaningful, you need a server-side invalidation check.
- The simplest MVP approach that preserves stateless deployment:
  - Add `iat` claim (UTC unix seconds) to tokens.
  - Add `User.token_invalid_before` (UTC unix seconds).
  - On each authenticated request, reject if `iat <= token_invalid_before`.
  - On logout, bump `token_invalid_before`.

### Testing + fixtures notes

- The integration tests override `get_async_session` (see `backend/tests/conftest.py`).
- Avoid writing auth logic that opens DB sessions via `async_session_factory` directly inside a Starlette middleware, or tests may hit the wrong DB.
- Prefer a dependency that receives `AsyncSession = Depends(get_async_session)`.

### Previous story intelligence (important)

- `passlib==1.7.4` can break with `bcrypt>=5` on newer Python; this repo pinned `bcrypt<5` for stability.
  - Do not remove or loosen that pin when touching auth dependencies.

### Git intelligence (recent work patterns)

- Recent commits show Epic 2 auth work landed as focused, layered changes:
  - `feat(auth): implement user registration API endpoint (Story 2.1)`
  - `feat(auth): implement user login API endpoint (Story 2.2)`
- Keep the same pattern: small modules, strict router→service→repository boundaries, and integration tests per endpoint.

### Latest technical info (web research used for correctness)

- FastAPI security pattern strongly favors dependency-based “current user” extraction with Bearer tokens.
  - Source: https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/ ("Authorization" Bearer header pattern + "get current user" dependency).
- `python-jose` is the JWT implementation already chosen in architecture and currently used in code.
  - Source: https://python-jose.readthedocs.io/en/latest/jwt/api.html (JWT API reference; use its exceptions to distinguish expired vs invalid tokens).

### Out of scope (do not implement here)

- Refresh-token rotation / refresh endpoint.
- Multi-device session management (logout invalidates all prior tokens is fine for MVP).
- RBAC/roles.

### References

- Planning: `_bmad-output/planning-artifacts/epics.md` → “Story 2.3: JWT Authentication Middleware and Logout”
- Architecture: `_bmad-output/planning-artifacts/architecture.md` → “Authentication & Security”, “Error Handling Standards”, “Architectural Boundaries”
- Project rules: `_bmad-output/project-context.md` → “Authentication Rules”, “API Response Formats”, “Critical Don't-Miss Rules”
- Previous story learnings:
  - `_bmad-output/implementation-artifacts/2-1-user-registration-api-endpoint.md`
  - `_bmad-output/implementation-artifacts/2-2-user-login-api-endpoint.md`
- Current code touchpoints:
  - `backend/app/services/auth/jwt_service.py`
  - `backend/app/routers/auth.py`
  - `backend/app/models/user.py`
  - `backend/app/repositories/user_repository.py`
  - `backend/tests/conftest.py`

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex (GitHub Copilot)

### Debug Log References

- `python -m pytest tests/integration/test_auth_logout.py` (red phase: 5 failing tests)
- `python -m pytest tests/integration/test_auth_logout.py` (green phase: 5 passing tests)
- `python -m pytest` (full regression: 22 passing tests)
- `python -m ruff check .` (quality gate: passing after import formatting fix)

### Completion Notes List

- Implemented `get_current_user` auth dependency with standardized 401 error mapping (`TOKEN_EXPIRED` and `INVALID_TOKEN`) and `CurrentUser` alias.
- Added `/api/v1/auth/logout` endpoint that uses dependency-authenticated user context and service-layer logout behavior.
- Implemented invalidate-by-time session invalidation via `User.token_invalid_before` and JWT `iat` claim checks.
- Added repository/service plumbing for user lookup by UUID and logout token invalidation updates.
- Added Alembic migration to add `token_invalid_before` with safe default.
- Added integration coverage for missing/malformed/expired token cases, successful logout, and token invalidation after logout.

### File List

- `backend/app/dependencies/__init__.py`
- `backend/app/dependencies/auth.py`
- `backend/app/models/user.py`
- `backend/app/repositories/user_repository.py`
- `backend/app/routers/auth.py`
- `backend/app/schemas/auth.py`
- `backend/app/services/auth/jwt_service.py`
- `backend/app/services/auth_service.py`
- `backend/alembic/versions/4c8ab44815f1_add_token_invalid_before_to_users.py`
- `backend/tests/integration/test_auth_logout.py`

## Change Log

- 2026-03-16: Implemented JWT auth dependency, logout endpoint, invalidate-by-time token revocation (`iat` + `token_invalid_before`), migration, and full integration tests for Story 2.3.
