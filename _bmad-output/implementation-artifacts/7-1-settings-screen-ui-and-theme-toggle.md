# Story 7.1: Settings Screen UI & Theme Toggle

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user,
I want a dedicated Settings screen to view my account info and customize app appearance,
so that I can manage my preferences.

## Acceptance Criteria

1. **Given** I am on the Settings tab
   **When** the screen loads
   **Then** I see my account email displayed at the top

2. **And** I see options for: "Theme" (Dark/Light toggle), "Reset Password", "Delete Account", and "Logout"

3. **And** toggling the Theme instantly updates the app appearance (rebuilding with light/dark theme)

4. **And** the UI consumes design tokens and is fully polished

## Tasks / Subtasks

- [x] Mobile: add a global theme-mode state holder (AC: 2, 3)
  - [x] Create a lightweight Riverpod provider (sync) for theme mode (session-only; no persistence)
  - [x] Provide explicit actions/methods to set Light and Dark (avoid toggle ambiguity in tests)
  - [x] Default to **dark mode** (dark-first UX direction)
  - [x] Suggested location: `mobile/lib/features/settings/providers/theme_mode_provider.dart` (create folder)

- [x] Mobile: bind themeMode into `MaterialApp.router` (AC: 3)
  - [x] Update `mobile/lib/app.dart` to `ref.watch()` the theme mode provider
  - [x] Replace the hardcoded `themeMode: ThemeMode.dark` with the provider value
  - [x] Keep `theme: AppTheme.lightTheme` and `darkTheme: AppTheme.darkTheme` intact

- [x] Mobile: implement Settings screen UI (AC: 1, 2, 4)
  - [x] Update `mobile/lib/features/settings/screens/settings_screen.dart`
  - [x] Render an app bar/title (match existing patterns like `LibraryScreen`)
  - [x] Email header:
    - [x] Read from `authStateProvider` (`mobile/lib/features/auth/providers/auth_provider.dart`)
    - [x] Show email (nullable-safe) prominently at the top when authenticated
    - [x] If auth is still resolving, show a small loading/skeleton using existing shimmer primitives (optional but recommended)
  - [x] Options list includes exactly these rows (visible labels match AC):
    - [x] Theme: Dark / Light (two explicit choices)
    - [x] Reset Password (UI only in 7.1; behavior implemented in Story 7.2)
    - [x] Delete Account (UI only in 7.1; behavior implemented in Story 7.4)
    - [x] Logout (can be functional in 7.1 using existing `AuthNotifier.logout()`)
  - [x] Theme switching:
    - [x] Selecting Dark sets provider to `ThemeMode.dark`
    - [x] Selecting Light sets provider to `ThemeMode.light`
    - [x] Ensure selection state is visually clear using tokens (no hardcoded colors)
  - [x] Reset Password / Delete Account stubs:
    - [x] Keep them visible but do not implement network calls or new routes here
    - [x] Prefer `onTap: null` / disabled styling, or a no-op with TODO linking to Story 7.2 / 7.4
  - [x] Logout:
    - [x] Call `ref.read(authStateProvider.notifier).logout()`
    - [x] Rely on existing router redirect logic in `mobile/lib/router.dart` to return to login
  - [x] Design-system + accessibility guardrails:
    - [x] Use `DocuMindTokens` via `Theme.of(context).extension<DocuMindTokens>()!` for colors
    - [x] Use `AppSpacing` constants for spacing (`mobile/lib/core/theme/app_spacing.dart`)
    - [x] Use `theme.textTheme` for text styles
    - [x] Ensure all touch targets are ≥ 44×44pt (matches accessibility epic requirements)
    - [x] Add Semantics labels for interactive rows and the email header

- [x] Tests: Settings screen widget coverage (AC: 1–4)
  - [x] Add `mobile/test/widget/settings_screen_test.dart`
  - [x] Provide a minimal test harness using `ProviderScope` + `MaterialApp.router` like existing widget tests
  - [x] Assert email is shown when authenticated
  - [x] Assert Theme option shows both Light and Dark choices
  - [x] Assert switching theme updates `MaterialApp.router.themeMode` (or observable UI surface color)
  - [x] Avoid `pumpAndSettle()` for theme transitions; use bounded `pump(const Duration(...))`

## Dev Notes

### Ground truth: existing code touchpoints (reuse-first)

- Settings route already exists:
  - `mobile/lib/router.dart` exposes `path: '/settings'` and uses `const SettingsScreen()`
- Theme is currently forced to dark:
  - `mobile/lib/app.dart` sets `themeMode: ThemeMode.dark` and must be made provider-driven
- Design tokens are already available via ThemeExtension:
  - `mobile/lib/core/theme/theme_extensions.dart` defines `DocuMindTokens(colors: ...)`
  - `mobile/lib/core/theme/app_colors.dart` defines the `AppColorPalette` fields you should use (e.g., `surfacePrimary`, `textPrimary`, `accentPrimary`, `accentError`)
- Spacing tokens exist:
  - `mobile/lib/core/theme/app_spacing.dart` (`xs`, `sm`, `md`, `lg`, `xl`, `x2l`, `x3l`)
- Auth state is already centralized:
  - `mobile/lib/features/auth/providers/auth_provider.dart` (AsyncNotifier) provides `AuthState.userEmail` and `AuthNotifier.logout()`

### Scope boundaries (do NOT exceed)

- No new settings sub-pages, routes, dialogs, or flows in Story 7.1.
- No persistence for theme preference in Story 7.1 (session-only). Do not add `SharedPreferences`/storage.
- Reset Password and Delete Account are UI placeholders only in 7.1; behavior is implemented in Stories 7.2 and 7.4.

### Common pitfalls to prevent

- Don’t hardcode colors/spacing/font sizes; always use tokens.
- Don’t keep `themeMode: ThemeMode.dark` in `MaterialApp.router`.
- Don’t implement backend calls from the Settings screen (router/service separation).

### Project Structure Notes

- Prefer feature-based placement:
  - `mobile/lib/features/settings/providers/` for theme mode provider
  - `mobile/lib/features/settings/screens/settings_screen.dart` for UI
- Do not modify theme token definitions (`mobile/lib/core/theme/app_colors.dart`, `app_theme.dart`) unless the story explicitly requires it (it doesn’t).

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` → Epic 7 → Story 7.1]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` → Design System Foundation → Dark Mode First + Theme Extension]
- [Source: `_bmad-output/project-context.md` → Flutter rules + theme token rules + accessibility]
- [Source: `mobile/lib/app.dart` → `themeMode` currently hardcoded]
- [Source: `mobile/lib/router.dart` → `/settings` route]

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex (GitHub Copilot)

### Debug Log References

- `flutter test mobile/test/widget/settings_screen_test.dart` (initial run: 1 assertion mismatch, fixed)
- `flutter test` (full mobile suite: 1 legacy assertion mismatch in `widget_test.dart`, fixed)
- `flutter analyze` (mobile: no issues)

### Completion Notes List

- Added `themeModeProvider` as a session-only synchronous Riverpod `Notifier` with explicit `setDark()` and `setLight()` actions, defaulting to dark mode.
- Bound `MaterialApp.router.themeMode` in `mobile/lib/app.dart` to `ref.watch(themeModeProvider)` while preserving light and dark theme definitions.
- Replaced Settings placeholder UI with a token-driven screen: app bar, authenticated email header (with shimmer loading state), explicit Dark/Light controls, disabled Reset Password/Delete Account rows, and functional Logout action via `authStateProvider.notifier.logout()`.
- Added semantics labels and ensured interactive controls maintain minimum touch target sizing.
- Added widget tests in `mobile/test/widget/settings_screen_test.dart` covering authenticated email rendering, explicit theme choices, and runtime `MaterialApp.router.themeMode` changes without `pumpAndSettle()`.
- Updated existing `mobile/test/widget_test.dart` assertion to reflect the new Settings UI output.

### File List

- `mobile/lib/app.dart`
- `mobile/lib/features/settings/providers/theme_mode_provider.dart`
- `mobile/lib/features/settings/screens/settings_screen.dart`
- `mobile/test/widget/settings_screen_test.dart`
- `mobile/test/widget_test.dart`

## Senior Developer Review (AI)

- **Outcome**: Approve
- **Date**: 2026-03-21

### AC Validation
- [x] AC 1: Authenticated email header uses auth provider, displays email correctly with loading shimmer state.
- [x] AC 2: Theme, Reset Password, Delete Account, Logout options are rendered.
- [x] AC 3: Theme instantly updates dynamically using Riverpod `themeModeProvider` bound to `MaterialApp.router`.
- [x] AC 4: Fully polished using design tokens (`DocuMindTokens`) and standard sizes (`minHeight: 44`).

### Task Audit
- All listed tasks marked complete have been verified with implementation matching expectation.
- Test coverage covers authentic email rendering, dark/light toggle switches and asserting correctly direct assertions.

### Code Quality & Security
- Complete adherence to design patterns using theme extensions and token variables.
- Accessibility compliance enforced via Semantic labels and correctly scaled layouts.

## Change Log

- 2026-03-21: Implemented Story 7.1 settings UI/theme toggle, added widget coverage, and validated with full mobile tests + analyzer.
- 2026-03-21: AI Code Review Complete - Clean approve.

