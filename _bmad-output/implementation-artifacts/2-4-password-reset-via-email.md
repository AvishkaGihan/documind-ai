# Story 2.4: Password Reset via Email

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a registered user who forgot my password,
I want to request a password reset link via email,
so that I can regain access to my account.

## Acceptance Criteria

1. **Given** I am a registered user who has forgotten my password
   **When** I send a POST request to `/api/v1/auth/reset-password` with my email
   **Then** a password reset token is generated and a reset link is sent to my email
   **And** a 200 response is returned (regardless of whether email exists, to prevent enumeration)

2. **Given** I have a valid password reset token
   **When** I send a POST request to `/api/v1/auth/reset-password/confirm` with the token and a new password (≥12 characters)
   **Then** my password is updated with bcrypt hashing and all existing sessions are invalidated

3. **Given** I have an expired or invalid reset token
   **When** I attempt to confirm the password reset
   **Then** a 400 Bad Request error is returned with `detail.code: "INVALID_RESET_TOKEN"`

## Tasks / Subtasks

- [x] Add password-reset request/confirm schemas (AC: 1–3)
  - [x] Update `backend/app/schemas/auth.py` (preferred: keep auth schemas consolidated) to add:
    - [x] `PasswordResetRequest` with `email: EmailStr`
    - [x] `PasswordResetConfirmRequest` with:
      - [x] `token: str` (min length should be reasonable; do not over-validate format)
      - [x] `new_password: str = Field(min_length=12)`
    - [x] `PasswordResetResponse` (mirror logout): `{ "status": "ok" }`

- [x] Implement reset-token creation + validation (AC: 1–3)
  - [x] Extend `backend/app/services/auth/jwt_service.py` with password-reset token helpers:
    - [x] `create_password_reset_token(subject: str, email: str | None = None) -> str`
      - Use the existing JWT secret (`JWT_SECRET_KEY`) and algorithm (`HS256`) for MVP simplicity.
      - Token payload must include:
        - `sub` (user UUID string)
        - `type == "reset"` (distinct from `access`/`refresh`)
        - `iat` (UTC unix seconds)
        - `exp` (short expiry; default 30 minutes)
        - optional `email` for debugging/auditing parity with other tokens
    - [x] (Optional) Add a small helper to decode and validate token type `reset` and return `user_id: UUID`.
  - [x] Update `backend/app/config.py` `Settings` with reset-token settings:
    - [x] `password_reset_token_expires_minutes: int` (env: `PASSWORD_RESET_TOKEN_EXPIRES_MINUTES`, default `30`)
    - [x] `password_reset_frontend_url: str` (env: `PASSWORD_RESET_FRONTEND_URL`)
      - Used to build reset links safely.
      - Must not be derived from request headers to avoid host header injection.

- [x] Add email sending abstraction (AC: 1)
  - [x] Create `backend/app/services/email_service.py` as the **sole** email side-channel integration point.
    - Keep it small and testable.
    - For MVP, it is acceptable to **log** the email (via `structlog`) when SMTP is not configured.
    - If SMTP is configured, send a plain-text email with the reset link.
  - [x] Implement it using FastAPI `BackgroundTasks` to keep response time uniform:
    - Router adds background task (preferred) to call `email_service.send_password_reset_email(...)`.

- [x] Add AuthService methods for password reset (AC: 1–3)
  - [x] Update `backend/app/services/auth_service.py`:
    - [x] Add domain exception: `InvalidResetTokenError`.
    - [x] Add `async def request_password_reset(self, email: str, background_tasks: BackgroundTasks) -> None`:
      - [x] Look up user by email using `get_by_email`.
      - [x] Always behave the same externally:
        - [x] If user exists: generate reset token + link and enqueue email send.
        - [x] If user does not exist: do nothing (but still return successfully).
      - [x] Do not reveal whether the email exists.
    - [x] Add `async def confirm_password_reset(self, token: str, new_password: str) -> None`:
      - [x] Validate token (`type == "reset"`, `sub` is UUID, not expired).
      - [x] If invalid/expired: raise `InvalidResetTokenError`.
      - [x] Load user by `sub` using repository `get_by_id`.
      - [x] Hash new password with existing hasher (`app/services/auth/password_hasher.py`).
      - [x] Update `user.hashed_password`.
      - [x] Invalidate all sessions by bumping `user.token_invalid_before = now_utc_unix_seconds`.
      - [x] Commit the transaction.

- [x] Add router endpoints (AC: 1–3)
  - [x] Update `backend/app/routers/auth.py` under `/api/v1/auth`:
    - [x] `POST /reset-password`:
      - [x] Accept `PasswordResetRequest`.
      - [x] Add a `BackgroundTasks` parameter.
      - [x] Call `AuthService.request_password_reset(...)`.
      - [x] Return `PasswordResetResponse(status="ok")`.
      - [x] Always return 200 (even if email not found).
    - [x] `POST /reset-password/confirm`:
      - [x] Accept `PasswordResetConfirmRequest`.
      - [x] Call `AuthService.confirm_password_reset(...)`.
      - [x] On `InvalidResetTokenError`, raise `HTTPException(400)` with:
        - `detail = build_error_detail(code="INVALID_RESET_TOKEN", message="Invalid or expired reset token.")`
      - [x] Return `PasswordResetResponse(status="ok")`.

- [x] Add integration tests (AC: 1–3)
  - [x] Add `backend/tests/integration/test_auth_password_reset.py` covering:
    - [x] Reset request returns 200 for an existing email (AC: 1)
    - [x] Reset request returns 200 for an unknown email (AC: 1; enumeration prevention)
    - [x] Confirm with malformed token returns 400 `INVALID_RESET_TOKEN` (AC: 3)
    - [x] Confirm with expired token returns 400 `INVALID_RESET_TOKEN` (AC: 3)
      - Generate an expired reset token using `jose.jwt.encode(...)` like `test_auth_logout.py` does.
    - [x] Confirm with valid token updates password (AC: 2)
      - Sign up user, generate reset token for that user id, call confirm, then:
        - login with new password succeeds
        - login with old password returns `INVALID_CREDENTIALS`
    - [x] Confirm invalidates sessions by bumping `token_invalid_before` (AC: 2)
      - Sign up, capture access token, confirm reset, then `/api/v1/auth/logout` with old access token returns 401 `INVALID_TOKEN`.

## Dev Notes

### What already exists (reuse; do not reinvent)

- Router/service layering: `backend/app/routers/auth.py` → `backend/app/services/auth_service.py`.
- Standard error payload builder: `backend/app/routers/errors.py` (`build_error_detail`).
- Request validation normalization: `backend/app/main.py` (422 → `VALIDATION_ERROR` with `field`).
- Password hashing utilities: `backend/app/services/auth/password_hasher.py`.
- JWT utilities + secret config:
  - `backend/app/services/auth/jwt_service.py`
  - `backend/app/config.py` (`JWT_SECRET_KEY`, expiry settings)
- Session invalidation mechanism already in place (Story 2.3):
  - `User.token_invalid_before` in `backend/app/models/user.py`
  - `iat` claim in access/refresh tokens and checks in `backend/app/dependencies/auth.py`

### Project Structure Notes

- Keep auth API endpoints in `backend/app/routers/auth.py` under the existing `/api/v1/auth` router.
- Keep business logic in `backend/app/services/auth_service.py`; routers should only translate HTTP ↔ domain.
- Keep JWT token primitives in `backend/app/services/auth/jwt_service.py` (do not duplicate encode/decode logic elsewhere).
- Introduce exactly one new integration boundary for email: `backend/app/services/email_service.py`.
- Keep DB access through repositories only (for this story, reuse `get_by_email` and `get_by_id`).

### Guardrails (security + correctness)

- Enumeration protection is mandatory: `/reset-password` must return 200 for both existing and non-existing emails.
- Avoid host header injection: build reset links from a trusted configured base URL (settings), not from request headers.
- Token type separation is mandatory:
  - Reset token must have `type == "reset"` and must not be accepted anywhere else.
  - Access/refresh tokens must not be accepted by reset confirmation.
- Do not automatically log the user in after reset.
- Keep responses uniform in time as much as practical.
  - Use `BackgroundTasks` for email send to reduce timing differences.

### Error formatting (must stay consistent)

- All errors must follow:
  - `{"detail": {"code": "...", "message": "...", "field": null}}`
- Use `build_error_detail(...)` for `INVALID_RESET_TOKEN`.

### Password hashing + dependency caveat

- Keep the existing bcrypt/passlib compatibility constraints.
  - This repo previously pinned `bcrypt<5` for stability; do not loosen that pin while touching auth.

### Git intelligence (recent work patterns)

- Recent work landed as focused, layered PRs with one integration-test file per endpoint group:
  - `feat(auth): implement user registration API endpoint (Story 2.1)`
  - `feat(auth): implement user login API endpoint (Story 2.2)`
  - `feat(auth): implement JWT authentication middleware and logout (Story 2.3)`
- Follow the same pattern: small modules, strict router→service→repository boundaries, and integration coverage.

### Latest technical info (web research used for correctness)

- OWASP notes for forgot-password flows:
  - Return consistent messaging for existent/non-existent accounts, use secure random tokens, short expiry, and avoid URL-building from the Host header.
  - Source: https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html
- FastAPI `BackgroundTasks` is appropriate for small async-adjacent work like sending email after responding.
  - Source: https://fastapi.tiangolo.com/tutorial/background-tasks/

### References

- Epic requirements: `_bmad-output/planning-artifacts/epics.md` → “Story 2.4: Password Reset via Email”
- Project rules: `_bmad-output/project-context.md` → “Authentication Rules”, “API Response Formats”, “Critical Don't-Miss Rules”
- Established auth patterns:
  - `backend/app/routers/auth.py`
  - `backend/app/services/auth_service.py`
  - `backend/app/dependencies/auth.py`
  - `backend/app/services/auth/jwt_service.py`
  - `backend/tests/integration/test_auth_*.py`

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex (GitHub Copilot)

### Debug Log References

- Red phase: `./.venv/bin/python -m pytest tests/integration/test_auth_password_reset.py -q` (6 failed, expected)
- Green phase: `./.venv/bin/python -m pytest tests/integration/test_auth_password_reset.py -q` (6 passed)
- Quality gates: `./.venv/bin/python -m ruff check app tests` (passed)
- Regression suite: `./.venv/bin/python -m pytest -q` (31 passed)

### Completion Notes List

- Implemented password reset request and confirm schemas in consolidated auth schema module.
- Added reset JWT creation/validation helpers with strict token-type separation (`type == "reset"`) and UUID subject validation.
- Added typed settings for reset token expiry and trusted reset frontend URL; reset link generation uses configured URL instead of request headers.
- Added `email_service` as the sole email side-channel boundary with `structlog` fallback when SMTP is not configured and SMTP send path when it is.
- Implemented `AuthService.request_password_reset` and `AuthService.confirm_password_reset` with enumeration-safe behavior and session invalidation via `token_invalid_before` bump.
- Added `/api/v1/auth/reset-password` and `/api/v1/auth/reset-password/confirm` endpoints with standardized `INVALID_RESET_TOKEN` errors.
- Added integration coverage for all ACs and unit coverage for reset JWT helpers.

### Senior Developer Review (AI)

**Date:** 2026-03-16
**Reviewer:** Antigravity (Adversarial AI)
**Outcome:** APPROVED

**Findings:**
- **AC Validation:** 100% Implemented. Verified `/api/v1/auth/reset-password` and `/api/v1/auth/reset-password/confirm` behavior.
- **Task Audit:** All tasks marked `[x]` are verified as fully implemented with matching logic in the codebase.
- **Security:** 
    - Enumeration protection confirmed in `AuthService.request_password_reset`.
    - Safe reset link building confirmed in `_build_password_reset_link` (no Host header dependency).
    - Strict token-type separation (`type == "reset"`) verified in JWT helpers.
- **Test Quality:** 9/9 tests passed (Integration + Unit). Coverage is real and asserts correct state transitions (password update + session invalidation).

**Changes Applied during Review:** None required. Implementation followed project-context.md and story requirements perfectly.

### File List

- `backend/app/schemas/auth.py`
- `backend/app/services/auth/jwt_service.py`
- `backend/app/services/auth_service.py`
- `backend/app/services/email_service.py`
- `backend/app/routers/auth.py`
- `backend/app/config.py`
- `backend/tests/integration/test_auth_password_reset.py`
- `backend/tests/unit/test_auth_jwt_service.py`

### Change Log

- 2026-03-16: Implemented Story 2.4 password reset flow (schemas, reset JWT helpers, trusted reset-link build, email service abstraction, auth service methods, router endpoints, integration and unit tests); all backend tests and lint checks passing.
