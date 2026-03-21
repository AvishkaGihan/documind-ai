# Story 7.2: Password Reset UI Flow

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user,
I want to trigger a password reset from the settings screen,
so that I can secure my account if needed.

## Acceptance Criteria

1. **Given** I am on the Settings screen
   **When** I tap "Reset Password"
   **Then** I am shown a confirmation dialog stating an email will be sent

2. **And** tapping "Confirm" calls the password reset endpoint

3. **And** a success SnackBar confirms the action

## Tasks / Subtasks

- [x] Mobile: enable "Reset Password" action from Settings (AC: 1)
  - [x] Update the existing row in `mobile/lib/features/settings/screens/settings_screen.dart` to be `enabled: true` and provide an `onTap` handler
  - [x] Keep the row styling/token usage consistent with Story 7.1 (no new widgets or routes)
  - [x] Update semantics label to reflect enabled behavior (not “unavailable”)

- [x] Mobile: confirmation dialog UX (AC: 1)
  - [x] On tap, show a confirmation dialog (Material `AlertDialog` via `showDialog`)
  - [x] Dialog content clearly states that a reset email will be sent to the currently authenticated email
  - [x] Provide two actions: "Cancel" (tertiary) and "Confirm" (primary)
  - [x] Ensure dialog buttons have ≥ 44×44pt touch targets
  - [x] While submitting, disable actions and show a small progress indicator in the confirm action (use `StatefulBuilder` in the dialog; do not introduce new providers)

- [x] Mobile: call existing password reset API (AC: 2)
  - [x] Use `authStateProvider` to read the authenticated email
  - [x] If email is null/blank or auth state is still loading/error, show a warning SnackBar and do not call the API
  - [x] Call the existing client method: `ref.read(authApiProvider).resetPassword(email: email)`
  - [x] Do not create any new API endpoints or new AuthApi methods

- [x] Mobile: feedback SnackBars (AC: 3)
  - [x] On success, show a green success SnackBar for ~3 seconds with a checkmark icon (use `tokens.colors.accentSecondary` for the background to avoid new token work)
  - [x] Success message should be user-friendly and non-leaky, e.g. “If an account exists, a password reset email has been sent.”
  - [x] On failure, use the existing error pattern:
    - [x] Prefer `showPersistentErrorSnackBar(context, tokens, error.message)` from `mobile/lib/shared/widgets/app_snackbar.dart`
    - [x] Keep message copy concise; avoid dialogs for non-critical errors

- [x] Tests: widget coverage for Settings password reset (AC: 1–3)
  - [x] Add/extend a widget test in `mobile/test/widget/` (either extend `settings_screen_test.dart` or add `settings_password_reset_test.dart`)
  - [x] Test baseline: tapping the Reset Password row opens the confirmation dialog
  - [x] Test confirm: confirming triggers `AuthApi.resetPassword()` with the authenticated email
  - [x] Test success: shows a SnackBar with the success message
  - [x] Test failure: shows an error SnackBar (persistent) when the API throws `AuthApiError`
  - [x] Avoid `pumpAndSettle()` timeouts; use bounded pumps like the existing `pumpFrames()` helper

## Dev Notes

### Ground truth: existing backend + mobile contracts (reuse-first)

- Backend password reset endpoints already exist (do NOT add `/api/v1/user/reset-password`):
  - `POST /api/v1/auth/reset-password` (request)
  - `POST /api/v1/auth/reset-password/confirm` (confirm)
  - Implementation: `backend/app/routers/auth.py` and `backend/app/services/auth_service.py`

- Request/response contract for the Settings-triggered reset request:
  - Request: `POST /api/v1/auth/reset-password` with JSON body `{"email": "user@example.com"}`
  - Response: `200 OK` with JSON `{"status": "ok"}`
  - Notes: Endpoint intentionally returns `ok` even if the email does not exist (avoid account enumeration). Use a non-leaky success SnackBar copy.

- Mobile API client already supports password reset:
  - `AuthApi.resetPassword({required String email})` → `POST /api/v1/auth/reset-password`
  - File: `mobile/lib/features/auth/data/auth_api.dart`

- How to read the current email safely in Settings:
  - `final authState = ref.read(authStateProvider);` (or reuse the watched value)
  - Prefer `authState.value?.userEmail` when `authState` is an `AsyncValue<AuthState>`
  - Guard: if `authState.isLoading`, `authState.hasError`, or email is null/blank → show warning and bail

- There is already a “Forgot password?” flow on the Login screen using a bottom sheet and manual email entry:
  - File: `mobile/lib/features/auth/screens/login_screen.dart`
  - Story 7.2 is specifically for Settings (authenticated flow) and should not require re-entering email.

### UX / design-system compliance

- SnackBar feedback rules (from UX spec):
  - Success: green SnackBar, auto-dismiss (~3s)
  - Error: red SnackBar, persistent, optional retry
  - Prefer SnackBars for non-critical info; dialogs are only for confirmations

- Token usage rules (must follow):
  - No hardcoded colors/spacing; use `DocuMindTokens` (`Theme.of(context).extension<DocuMindTokens>()!`) and `AppSpacing`
  - Use `accentSecondary` (green) for success background; use existing `accentError` for failures

### Architecture guardrails (do not violate)

- Keep logic in UI thin: Settings onTap should orchestrate dialog + call `AuthApi` only; avoid creating new state management layers.
- Do not introduce new routes/pages for reset-password in this story.
- Do not implement deep linking or an in-app token confirmation screen here; backend currently generates a link using `PASSWORD_RESET_FRONTEND_URL`.

### Previous story intelligence (Epic 7 / Story 7.1 learnings)

- Settings screen is already token-driven and uses `_SettingsActionRow` with `enabled` gating.
- Widget tests in this repo can be flaky with unbounded settles; use bounded `pump(Duration(...))` steps.
- Theme mode is provider-driven; keep Story 7.2 changes local to the settings screen and tests.

### Git intelligence (recent work patterns)

- The most recent relevant change set is Story 7.1 (Settings UI + tests). Follow those patterns for provider overrides and router harness in widget tests.

### References

- Epic/story intent: `_bmad-output/planning-artifacts/epics.md` → Epic 7 → Story 7.2
- UX feedback patterns: `_bmad-output/planning-artifacts/ux-design-specification.md` → “Feedback Patterns”
- Project rules: `_bmad-output/project-context.md` → Flutter rules + token rules + testing rules
- Backend contract: `backend/app/routers/auth.py` → reset-password routes
- Mobile contract: `mobile/lib/features/auth/data/auth_api.dart` → `resetPassword()`
- Settings implementation: `mobile/lib/features/settings/screens/settings_screen.dart`

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex (GitHub Copilot)

### Debug Log References

- `flutter test test/widget/settings_screen_test.dart`
- `flutter test`
- `flutter analyze`

### Completion Notes List

- Enabled the existing Settings "Reset Password" action row with updated enabled semantics and an `onTap` handler.
- Implemented confirmation dialog flow using `AlertDialog` + `StatefulBuilder`, including disabled actions and inline progress indicator while submitting.
- Reused `authStateProvider` for authenticated email lookup with loading/error/blank guards and warning SnackBar fallback.
- Called existing `AuthApi.resetPassword(email: email)` without creating new API methods/routes.
- Added success SnackBar (green via `tokens.colors.accentSecondary`) and failure handling via `showPersistentErrorSnackBar(...)`.
- Extended widget tests to cover dialog opening, API invocation with email, success feedback, and error feedback.
- Verified regression and quality gates with full mobile test suite and analyzer.

### File List

- `mobile/lib/features/settings/screens/settings_screen.dart`
- `mobile/test/widget/settings_screen_test.dart`

## Change Log

- 2026-03-22: Implemented Story 7.2 Settings password reset UI flow, added widget coverage, and validated with `flutter test` + `flutter analyze`.

## Story Completion Status

- Status set to `review`
- Ultimate context engine analysis completed - comprehensive developer guide created
