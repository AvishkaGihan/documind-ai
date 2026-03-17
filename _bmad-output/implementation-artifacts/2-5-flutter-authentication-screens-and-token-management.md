# Story 2.5: Flutter Authentication Screens and Token Management

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a mobile user,
I want to see polished login and signup screens and have my session persist securely,
so that I can authenticate and stay logged in across app restarts.

## Acceptance Criteria

1. **Given** I open the app without a saved token
   **When** the app loads
   **Then** I am redirected to the Login screen with email and password fields, a sign-up link, and a forgot password link
   **And** the screens use the design token system (dark mode, Inter font, accent colors, proper spacing)

2. **Given** I fill in valid credentials on the Login screen
   **When** I tap the Login button
   **Then** the button shows a loading state, the API is called, the JWT token is securely stored using `flutter_secure_storage`, and I am navigated to the Document Library

3. **Given** I fill in valid details on the Signup screen
   **When** I tap the Sign Up button
   **Then** a new account is created, the token is stored, and I am navigated to the Welcome/Library screen

4. **Given** I have a saved valid token from a previous session
   **When** I open the app
   **Then** I am automatically logged in and taken to the Document Library without seeing the login screen

5. **And** form fields show real-time inline validation (email format, password length ≥12)
   **And** error messages appear below the relevant field, not as alerts
   **And** all touch targets meet the 44×44pt minimum requirement

## Tasks / Subtasks

- [x] Implement auth bootstrap so auto-login never flashes the login screen (AC: 1, 4)
  - [x] Update `mobile/lib/router.dart` redirect to handle auth state loading explicitly (do not treat `AsyncLoading` as unauthenticated).
  - [x] Add a minimal public bootstrap route (recommended: `/`) that shows a tokenized loading state while auth is resolving.
  - [x] Update `initialLocationProvider` to return `/` (or equivalent bootstrap location) so the first rendered screen is never a protected route while auth state is unknown.
  - [x] Ensure: with a stored valid token, the first meaningful screen shown is `/library` (no login placeholder flash).

- [x] Add token storage service using `flutter_secure_storage` (AC: 2–4)
  - [x] Create `mobile/lib/features/auth/data/token_storage.dart` (or similar) as the sole token persistence boundary.
  - [x] Store at minimum:
    - [x] `access_token`
    - [x] `refresh_token`
    - [x] (Optional) `user_id`, `email` (convenience for UI; not required for AC)
  - [x] Provide a Riverpod provider for the storage service so tests can override it.
  - [x] Never use `SharedPreferences` for tokens.

- [x] Add auth API client wrapper (Dio) to call backend endpoints (AC: 2–3)
  - [x] Create `mobile/lib/core/networking/dio_provider.dart` (or equivalent) to construct a single `Dio` instance.
  - [x] Base URL configuration:
    - [x] Use a compile-time environment value (recommended: `String.fromEnvironment('DOCUMIND_API_BASE_URL', defaultValue: ...)`) or a small config provider.
    - [x] Note emulator pitfall: Android emulator cannot reach the host backend via `localhost`; prefer `10.0.2.2:8000` for Android emulator and `localhost:8000` for iOS simulator.
  - [x] Create `mobile/lib/features/auth/data/auth_api.dart` with methods:
    - [x] `Future<LoginResponse> login({required String email, required String password})`
    - [x] `Future<SignUpResponse> signup({required String email, required String password})`
  - [x] Use the backend contract exactly:
    - [x] `POST /api/v1/auth/login` with JSON `{ "email": ..., "password": ... }`
    - [x] `POST /api/v1/auth/signup` with JSON `{ "email": ..., "password": ... }`
    - [x] Response shape:
      - [x] `user: { id, email }`
      - [x] `tokens: { access_token, refresh_token, token_type }`

- [x] Upgrade `authStateProvider` into real auth/session state (AC: 1–4)
  - [x] Update `mobile/lib/features/auth/providers/auth_provider.dart` to:
    - [x] On `build()`, load tokens from `TokenStorage`.
    - [x] Determine authenticated vs unauthenticated.
      - [x] Minimum: token presence.
      - [x] Recommended: decode JWT `exp` and treat expired token as unauthenticated (no refresh flow exists yet).
    - [x] Expose `Future<void> login(...)` and `Future<void> signup(...)`:
      - [x] Set state to loading while request is in-flight.
      - [x] On success: persist tokens; set authenticated; trigger router refresh.
      - [x] On error: keep unauthenticated and surface field-level error info for inline rendering.
    - [x] Expose `Future<void> logout()`:
      - [x] Clear secure storage.
      - [x] Set unauthenticated.
  - [x] Prefer `@freezed` state modeling once the state holds more than a boolean.

- [x] Implement Login and Signup screens with design tokens and inline validation (AC: 1–3, 5)
  - [x] Replace placeholders:
    - [x] `mobile/lib/features/auth/screens/login_screen.dart`
    - [x] `mobile/lib/features/auth/screens/signup_screen.dart`
  - [x] UI requirements:
    - [x] Email + password fields.
    - [x] Real-time validation (email format; password length ≥12).
    - [x] Errors render *below the field* (no alerts/popups).
    - [x] Submit button disabled until form valid.
    - [x] Submit button shows loading state while request runs.
    - [x] 44×44pt minimum touch targets (links and buttons included).
    - [x] Use tokens only (`DocuMindTokens`, `AppSpacing`, theme typography); no hard-coded colors/spacing.
  - [x] Navigation requirements:
    - [x] Login screen has link to `/auth/signup`.
    - [x] Signup screen has link to `/auth/login`.
    - [x] Successful auth navigates to `/library`.
  - [x] Forgot password link (AC: 1):
    - [x] Must be present.
    - [x] Keep scope minimal:
      - [x] Either a non-functional link (with TODO) is acceptable only if explicitly agreed.
      - [x] Preferred: open a small tokenized modal/bottom sheet that calls `POST /api/v1/auth/reset-password` (already implemented in backend Story 2.4) and shows an inline confirmation message.

- [x] Update tests to reflect real auth screens and auto-login (AC: 1–4)
  - [x] Update `mobile/test/widget_test.dart`:
    - [x] Replace placeholder text assertions with stable widget keys or semantic text.
    - [x] Keep unauthenticated redirect coverage.
    - [x] Add an auto-login test by overriding `TokenStorage` provider to return a stored token and asserting first meaningful route is Library.
  - [x] Add at least one widget test for inline validation (email/password) and error placement under fields.

## Dev Notes

### What already exists (reuse; do not reinvent)

- Routing + auth guard shell:
  - `mobile/lib/router.dart` already defines `/auth/login`, `/auth/signup`, `/library`, `/chat/:documentId`, `/settings` and has redirect rules.
- Auth state provider exists but is currently debug-only:
  - `mobile/lib/features/auth/providers/auth_provider.dart` uses `DOCUMIND_DEBUG_AUTH`.
- Design token system foundation exists and must be used:
  - `mobile/lib/core/theme/app_theme.dart`
  - `mobile/lib/core/theme/theme_extensions.dart` (`DocuMindTokens`)
  - `mobile/lib/core/theme/app_spacing.dart`
- Backend endpoints are implemented and stable:
  - `POST /api/v1/auth/login`
  - `POST /api/v1/auth/signup`
  - Password reset endpoints exist if you wire the UI link:
    - `POST /api/v1/auth/reset-password`

### API error mapping (inline field errors)

Backend uses standardized error payloads:

- `INVALID_CREDENTIALS` (401) → show under password field (or a form-level message directly under the submit button).
- `EMAIL_ALREADY_EXISTS` (409) → show under email field on Signup.
- `VALIDATION_ERROR` (422) with `detail.field` (`email` or `password`) → show under that field.

Do not display these errors as alerts/popups.

### Architecture + project rules to follow (non-negotiable)

- State management: Riverpod 3.x with `AsyncNotifier` for async state.
- Token storage: `flutter_secure_storage` only.
- UI: use Material 3 + theme tokens; no hardcoded colors/spacing.
- Touch targets: minimum 44×44pt.

### Project Structure Notes

- Follow the existing feature-based structure already present under `mobile/lib/features/`.
- Recommended locations (keep minimal; do not create duplicate layers):
  - Auth UI: `mobile/lib/features/auth/screens/`
  - Auth state: `mobile/lib/features/auth/providers/`
  - Auth I/O boundaries (API + secure storage): `mobile/lib/features/auth/data/`
  - Shared networking setup: `mobile/lib/core/networking/`
- Do not move or rename existing public routes in `mobile/lib/router.dart`.

### Guardrails (avoid common regressions)

- Do not break existing route paths; other stories depend on them.
- Do not introduce a second HTTP client; use `dio` (already in `pubspec.yaml`).
- Do not treat `AsyncLoading` as unauthenticated in router redirects; otherwise stored-token sessions will briefly show login.
- No refresh-token flow exists yet; do not invent new backend endpoints.

### References

- Epic requirements: `_bmad-output/planning-artifacts/epics.md` → “Story 2.5: Flutter Authentication Screens and Token Management”
- UX form rules + 44×44 targets: `_bmad-output/planning-artifacts/ux-design-specification.md` → “Form Patterns”, “Button rules”
- Architecture (JWT storage, routes, Riverpod): `_bmad-output/planning-artifacts/architecture.md` → “Authentication & Security”, “Frontend Architecture”
- Project rules (tokens, secure storage, AsyncNotifier): `_bmad-output/project-context.md` → “Flutter (Frontend)”, “Authentication Rules”
- Backend response contract: `backend/app/schemas/auth.py`
- Current mobile touchpoints:
  - `mobile/lib/router.dart`
  - `mobile/lib/features/auth/providers/auth_provider.dart`
  - `mobile/lib/features/auth/screens/login_screen.dart`
  - `mobile/lib/features/auth/screens/signup_screen.dart`

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex (GitHub Copilot)

### Debug Log References

- `flutter test test/widget_test.dart` (red phase): failed as expected before implementation
- `flutter test test/widget_test.dart` (green phase): all tests passed
- `flutter test`: all tests passed
- `flutter analyze`: no issues found

### Completion Notes List

- Implemented a bootstrap auth route (`/`) and loading-aware redirects so async auth initialization never flashes the login UI.
- Added a secure token persistence boundary with `flutter_secure_storage` and Riverpod override support for testing.
- Added auth networking layer (`Dio` provider + auth API wrapper) using backend contracts for login/signup/reset-password.
- Replaced debug-only auth state with real async session state, token bootstrap, JWT expiration handling, and login/signup/logout flows.
- Replaced login/signup placeholders with tokenized Material 3 forms including inline validation, field-level backend error mapping, loading buttons, 44x44 touch targets, and navigation links.
- Added forgot-password bottom sheet flow that calls `POST /api/v1/auth/reset-password` and renders inline confirmation/error messages.
- Updated widget tests for unauthenticated redirect, bootstrap auto-login via token storage override, and inline validation error rendering.

### File List

- `mobile/lib/router.dart`
- `mobile/lib/features/auth/screens/auth_bootstrap_screen.dart`
- `mobile/lib/features/auth/data/token_storage.dart`
- `mobile/lib/core/networking/dio_provider.dart`
- `mobile/lib/features/auth/data/auth_api.dart`
- `mobile/lib/features/auth/providers/auth_provider.dart`
- `mobile/lib/features/auth/screens/login_screen.dart`
- `mobile/lib/features/auth/screens/signup_screen.dart`
- `mobile/test/widget_test.dart`

## Change Log

- 2026-03-17: Implemented Story 2.5 authentication UI and session management end-to-end; added bootstrap routing, secure token storage, auth API integration, provider/session updates, and regression/widget tests.
