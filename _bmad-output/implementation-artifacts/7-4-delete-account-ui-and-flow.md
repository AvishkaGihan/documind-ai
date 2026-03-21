# Story 7.4: Delete Account UI & Flow

Status: done


<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user,
I want to be able to delete my account from the mobile app,
so that I can remove my data completely.

## Acceptance Criteria

1. **Given** I am on the Settings screen
   **When** I tap "Delete Account"
   **Then** a high-warning red Dialog appears asking for confirmation

2. **And** after confirming, the backend is called to delete the account

3. **And** upon success, I am logged out and returned to the Login screen with a confirmation message

## Tasks / Subtasks

- [x] Mobile: enable the "Delete Account" settings row (AC: 1)
  - [x] Update `mobile/lib/features/settings/screens/settings_screen.dart` to set the Delete Account row `enabled: true` and provide an `onTap`
  - [x] Update the semantics label to reflect enabled behavior (avoid “unavailable” wording)
  - [x] Keep row styling/token usage consistent with Stories 7.1/7.2 (no new widgets/routes)

- [x] Mobile: destructive confirmation dialog UX (AC: 1)
  - [x] Show a Material confirmation dialog (use `showDialog` + `AlertDialog` pattern like Reset Password)
  - [x] Dialog copy must clearly communicate irreversibility and scope:
    - [x] Account will be deleted
    - [x] Documents, embeddings, and conversations will be deleted
    - [x] Action cannot be undone
  - [x] Visual high-warning emphasis using design tokens only:
    - [x] Title and/or icon uses `tokens.colors.accentError`
    - [x] Confirm button is visually destructive (error-accent background)
  - [x] Provide two actions:
    - [x] Cancel (tertiary)
    - [x] Delete (destructive)
  - [x] While submitting: disable actions and show small progress indicator in the destructive action
  - [x] Ensure dialog buttons have ≥ 44×44pt touch targets

- [x] Mobile: add API client for account deletion (AC: 2)
  - [x] Create `mobile/lib/features/settings/data/user_api.dart` (new) containing:
    - [x] `UserApi` wrapper around Dio
    - [x] `Future<void> deleteMe()` calling `DELETE /api/v1/user/me`
    - [x] Expect success: **204 No Content** with empty body (do not attempt JSON parsing)
    - [x] Error mapping that respects project error envelope:
      - [x] If response contains `{"detail": {"code": ..., "message": ..., "field": ...}}`, surface `message` for UI
      - [x] Otherwise map to a safe network fallback message (similar to `AuthApi._mapError`)
    - [x] `userApiProvider` (Riverpod `Provider<UserApi>`) reading `dioProvider`
  - [x] Do not add new endpoints; backend contract already exists (Story 7.3)

- [x] Mobile: wire delete flow + logout behavior (AC: 2, 3)
  - [x] In Settings delete-confirm handler, call `await ref.read(userApiProvider).deleteMe()`
  - [x] On success:
    - [x] Trigger logout via `await ref.read(authStateProvider.notifier).logout()`
    - [x] Ensure user ends up on Login screen (router redirect should handle this)
  - [x] On failure:
    - [x] Do not logout
    - [x] Show error using `showPersistentErrorSnackBar(context, tokens, error.message)`

- [x] Mobile: ensure the Login screen shows a post-deletion confirmation message (AC: 3)
  - [x] Implement a minimal “one-shot” flash message mechanism using Riverpod (avoid fighting `go_router` redirect semantics):
    - [x] Add `mobile/lib/features/auth/providers/auth_flash_message_provider.dart` (new) with a `StateProvider<String?>`
    - [x] Set the message (e.g., “Your account has been deleted.”) immediately before calling `logout()`
    - [x] In `mobile/lib/features/auth/screens/login_screen.dart`, read and display the message as a success SnackBar on first build/frame, then clear it
  - [x] Use design tokens for SnackBar styling (no hardcoded colors). Prefer `tokens.colors.accentSecondary` for success background.
  - [x] Keep copy user-safe and concise (no internal IDs).

- [x] Tests: widget coverage for delete account flow (AC: 1–3)
  - [x] Extend `mobile/test/widget/settings_screen_test.dart`
  - [x] Provide a fake `UserApi` (override `userApiProvider`) that:
    - [x] captures whether `deleteMe()` was called
    - [x] can be configured to throw a typed error to test failure UI
  - [x] Provide a fake auth notifier (override `authStateProvider`) that captures `logout()` calls without touching platform `flutter_secure_storage`
  - [x] Test: tapping Delete Account opens the destructive dialog
  - [x] Test: confirming calls `UserApi.deleteMe()`
  - [x] Test: on success, logout is called and a confirmation message is shown on the Login screen
  - [x] Test: on failure, persistent error SnackBar shows and logout is NOT called
  - [x] Avoid `pumpAndSettle()` flakiness; use bounded frame pumping like the existing `pumpFrames()` helper

## Dev Notes

### Ground truth: backend contract (do NOT guess)

- Backend endpoint already implemented and tested (Story 7.3):
  - `DELETE /api/v1/user/me`
  - Auth required (JWT via Dio interceptor)
  - Success: **204 No Content** (empty body)
  - Errors: standard envelope `{"detail": {"code": "...", "message": "...", "field": null}}`

### Ground truth: current mobile Settings implementation

- Settings screen location: `mobile/lib/features/settings/screens/settings_screen.dart`
- Delete Account row currently exists but is disabled:
  - Label: “Delete Account”
  - Key is derived from label: `settings-action-delete-account` (keep label stable to avoid test breakage)
- SnackBar helpers:
  - Persistent error: `showPersistentErrorSnackBar(...)` in `mobile/lib/shared/widgets/app_snackbar.dart`
  - Warning: `showWarningSnackBar(...)`

### UX + accessibility guardrails

- Destructive actions must require a confirmation dialog (UX spec).
- Use tokens only:
  - `DocuMindTokens` via `Theme.of(context).extension<DocuMindTokens>()!`
  - `AppSpacing` for spacing
- Minimum touch target size: ≥ 44×44pt for rows and dialog buttons.
- Add/adjust semantics labels for the Delete Account row and dialog actions.

### Architecture / project rules that apply

- Keep UI logic thin; put the network call behind an API wrapper (pattern used by `AuthApi`).
- Do not hardcode any colors or spacing.
- Prefer `ref.read()` only inside tap/confirm handlers; use `ref.watch()` for reactive UI.
- Avoid new routes/pages; this story is a single flow from Settings.

### Previous story intelligence (Epic 7)

- Story 7.1 established token-driven Settings UI + widget test harness patterns.
- Story 7.2 established dialog submission pattern (`StatefulBuilder`, disabled actions, inline spinner) and SnackBar conventions.
- Story 7.3 established the backend account deletion endpoint contract and error envelope.

### Git intelligence (recent work patterns)

- Recent commits touched:
  - `mobile/lib/features/settings/screens/settings_screen.dart` and `mobile/test/widget/settings_screen_test.dart` (Stories 7.1/7.2)
  - Backend user router/service/tests (Story 7.3)
- Keep changes consistent and localized; do not refactor unrelated Settings UI.

### Latest tech information (project-pinned)

- Flutter: 3.41 (Material 3)
- Riverpod: 3.2.1
- go_router: used for redirects; post-logout navigation relies on router redirect, so use a Riverpod flash message rather than `extra` navigation hacks.

### References

- Epic 7 / Story 7.4 BDD AC: `_bmad-output/planning-artifacts/epics.md` → Epic 7 → Story 7.4
- UX destructive confirmations + feedback patterns: `_bmad-output/planning-artifacts/ux-design-specification.md` → “Modal & Overlay Patterns”, “Feedback Patterns”
- Data deletion NFR: `_bmad-output/planning-artifacts/prd.md` → Non-Functional Requirements → Security → Data Deletion
- Mobile rules (tokens, Riverpod, testing): `_bmad-output/project-context.md`
- Current Settings implementation: `mobile/lib/features/settings/screens/settings_screen.dart`
- Backend delete-me endpoint details: `_bmad-output/implementation-artifacts/7-3-account-deletion-backend-endpoint.md`

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex (GitHub Copilot)

### Debug Log References

- `flutter test test/widget/settings_screen_test.dart`
- `flutter analyze lib/features/settings/screens/settings_screen.dart lib/features/settings/data/user_api.dart lib/features/auth/screens/login_screen.dart lib/features/auth/providers/auth_flash_message_provider.dart test/widget/settings_screen_test.dart`
- `flutter test`
- `flutter analyze`

### Completion Notes List

- Enabled the Settings delete-account action row and updated semantics to reflect an active destructive action.
- Added a destructive confirmation dialog using token-based styling, 44x44 minimum action targets, submission disabling, and inline progress indicator.
- Implemented `UserApi.deleteMe()` with `DELETE /api/v1/user/me`, 204 handling, and project-envelope error mapping with network fallback messaging.
- Wired delete success to set a one-shot auth flash message and then logout so router redirect sends the user to Login.
- Added Login-screen flash-message consumption on first frame and token-styled success SnackBar display.
- Extended settings widget tests to verify delete dialog rendering, API invocation, success logout+confirmation behavior, and failure SnackBar without logout.
- Full mobile regression and static analysis pass with no issues.

### File List

- `mobile/lib/features/settings/screens/settings_screen.dart`
- `mobile/lib/features/settings/data/user_api.dart`
- `mobile/lib/features/auth/providers/auth_flash_message_provider.dart`
- `mobile/lib/features/auth/screens/login_screen.dart`
- `mobile/test/widget/settings_screen_test.dart`
- `_bmad-output/implementation-artifacts/7-4-delete-account-ui-and-flow.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

### Change Log

- 2026-03-22: Implemented Story 7.4 mobile delete-account UX and flow, added API wrapper and auth flash-message mechanism, expanded widget coverage, and passed full mobile test/analyze validation.

## Story Completion Status

- Status set to `done`
- All tasks and subtasks completed; AC1-AC3 validated via widget tests and full mobile regression gates.
