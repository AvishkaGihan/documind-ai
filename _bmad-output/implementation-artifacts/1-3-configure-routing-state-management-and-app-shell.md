# Story 1.3: Configure Routing, State Management, and App Shell

Status: done

## Story

As a developer,
I want to set up `go_router` navigation with a bottom tab scaffold and wrap the app in Riverpod `ProviderScope`,
so that the app has a working navigation and state-management shell for all future feature screens.

## Acceptance Criteria

1. **Given** the Flutter project with design system is set up
   **When** I configure routing and state management
   **Then** `mobile/lib/router.dart` defines routes: `/auth/login`, `/auth/signup`, `/library`, `/chat/:documentId`, `/settings`

2. **Given** the app entry is wired
   **When** I structure the application root
   **Then** `mobile/lib/app.dart` wraps the app in `ProviderScope` and applies the custom `ThemeData`

3. **Given** the app needs a shared shell
   **When** I implement the scaffold
   **Then** `mobile/lib/shared/widgets/app_scaffold.dart` provides a bottom tab bar with Library (📚), Chat (💬), and Settings (⚙️) tabs

4. **Given** bottom tabs are present
   **When** I switch tabs
   **Then** tab navigation switches between placeholder screens for Library, Chat, and Settings

5. **Given** the bottom tab bar must match the design system
   **When** I style the tabs
   **Then** the bottom tab bar uses design tokens for styling (accent colors, minimum 44×44pt touch targets)

6. **Given** the user is not authenticated
   **When** they attempt to access authenticated routes
   **Then** unauthenticated routes redirect to `/auth/login`

## Tasks / Subtasks

- [x] Refactor app entrypoint to an app shell (AC: 2)
  - [x] Keep `mobile/lib/main.dart` minimal (calls `runApp(...)` only)
  - [x] Create `mobile/lib/app.dart` as the only widget that builds `ProviderScope` + `MaterialApp.router`
  - [x] Apply `AppTheme.lightTheme`, `AppTheme.darkTheme`, default `ThemeMode.dark` (preserve Story 1.2 behavior)

- [x] Implement routing with `go_router` (AC: 1, 4, 6)
  - [x] Create `mobile/lib/router.dart` and define the required paths:
    - [x] `/auth/login` (placeholder screen)
    - [x] `/auth/signup` (placeholder screen)
    - [x] `/library` (placeholder screen)
    - [x] `/chat/:documentId` (placeholder screen using `documentId`)
    - [x] `/settings` (placeholder screen)
  - [x] Use `StatefulShellRoute.indexedStack` (go_router 16.x) to implement tab routing with state preservation
  - [x] Ensure the tab destinations map cleanly to the required locations:
    - [x] Library tab → `/library`
    - [x] Chat tab → `/chat/active` (use a stable placeholder `documentId` such as `active` for this story)
    - [x] Settings tab → `/settings`
  - [x] Implement auth guarding via `GoRouter.redirect` using a Riverpod-backed auth state (see Dev Notes)

- [x] Implement shared bottom-tab scaffold widget (AC: 3, 4, 5)
  - [x] Create `mobile/lib/shared/widgets/app_scaffold.dart`
  - [x] Use Material 3 navigation component (`NavigationBar`) unless an existing project standard dictates otherwise
  - [x] Enforce minimum 44×44pt touch targets for each destination (padding, `NavigationDestination` sizing)
  - [x] Style using tokens from `DocuMindTokens` ThemeExtension:
    - [x] Background surface uses `tokens.colors.surfaceSecondary` (or `surfacePrimary` if contrast is better)
    - [x] Selected color uses `tokens.colors.accentPrimary`
    - [x] Unselected color uses `tokens.colors.textSecondary`
  - [x] Use label typography consistent with tokenized `TextTheme` (no hardcoded font sizes)

- [x] Create placeholder feature screens for routing targets (supports AC: 4)
  - [x] Create minimal placeholder screens (simple `Scaffold` + centered text) with no business logic:
    - [x] `mobile/lib/features/auth/screens/login_screen.dart`
    - [x] `mobile/lib/features/auth/screens/signup_screen.dart`
    - [x] `mobile/lib/features/library/screens/library_screen.dart`
    - [x] `mobile/lib/features/chat/screens/chat_screen.dart`
    - [x] `mobile/lib/features/settings/screens/settings_screen.dart`
  - [x] Ensure placeholders use theme tokens (background/text) and `const` constructors

- [x] Add minimal auth state provider for route guarding (AC: 6)
  - [x] Create `mobile/lib/features/auth/providers/auth_provider.dart`
  - [x] Implement an `AuthState` with a single boolean `isAuthenticated`
  - [x] Use Riverpod 3.x `AsyncNotifier` (per project rules) even if the implementation is a simple synchronous placeholder
  - [x] Default to unauthenticated for now (no token integration yet); confirm redirect behavior to `/auth/login`
  - [x] Ensure the router can still demonstrate tab navigation (see Dev Notes for the recommended local-dev approach)

- [x] Testing + static analysis (guardrails)
  - [x] Update/add widget tests to validate:
    - [x] App builds with `ProviderScope`
    - [x] Unauthenticated redirect to `/auth/login` happens for `/library` (or another protected route)
    - [x] Tab taps change active destination
  - [x] Run `flutter analyze` and `flutter test` and keep both green

## Dev Notes

### Architecture + project rules to follow (non-negotiable)

- **Routing library:** Use `go_router` only; do not introduce a second routing framework.
- **State management:** Use Riverpod 3.x with `AsyncNotifier` for async state. Avoid `setState()` for async flows.
- **Design tokens:** Do not hardcode colors, spacing, or fonts. Read from `DocuMindTokens` (`ThemeExtension`) and tokenized typography.
- **File naming:** Dart file names `snake_case` and classes `PascalCase`.

### Current codebase state (what exists today)

- `mobile/lib/main.dart` currently renders a `_ThemePreviewScreen` and does **not** use routing or Riverpod yet.
- The design system foundation exists and must remain the source of truth:
  - `mobile/lib/core/theme/app_theme.dart`, `app_colors.dart`, `app_typography.dart`, `app_spacing.dart`, `theme_extensions.dart`
- Dependencies are already added in `mobile/pubspec.yaml`:
  - `flutter_riverpod`, `go_router`, `dio`, `flutter_secure_storage`, `freezed` toolchain

### GoRouter tab-shell guidance (avoid common footguns)

- Prefer `StatefulShellRoute.indexedStack` for bottom tabs to preserve branch navigation state.
- Because the spec requires `/chat/:documentId` (no plain `/chat` route), use a stable placeholder location for the Chat tab in this story:
  - Recommended: `/chat/active` where `documentId == 'active'` shows a placeholder chat screen.

### Auth redirect guidance (keep it simple)

- Implement redirect rules in `GoRouter` based on a Riverpod auth state.
- **Protected routes** for now: `/library`, `/chat/:documentId`, `/settings`.
- **Public routes:** `/auth/login`, `/auth/signup`.
- The redirect logic should:
  - If not authenticated and user is navigating to a protected route → redirect to `/auth/login`.
  - If authenticated and user is navigating to `/auth/login` or `/auth/signup` → redirect to `/library`.

**Local-dev recommendation (to make AC verifiable without building full auth yet):**
- Provide a simple, explicit way for developers to simulate authentication in debug builds only (e.g., a hardcoded `isAuthenticated = true` in the provider, or an environment-based flag).
- Keep this scoped and easy to remove/replace in Epic 2.

### Project Structure Notes (align with architecture)

The architecture doc defines these paths; this story should create the missing ones rather than inventing new locations:
- `mobile/lib/app.dart`
- `mobile/lib/router.dart`
- `mobile/lib/shared/widgets/app_scaffold.dart`
- Feature placeholders under `mobile/lib/features/<feature>/screens/...` and `mobile/lib/features/auth/providers/...`

### References

- Story requirements + acceptance criteria: [Source: _bmad-output/planning-artifacts/epics.md → Epic 1 → Story 1.3]
- Mobile stack + routing/state decisions: [Source: _bmad-output/planning-artifacts/architecture.md → Frontend Architecture → Routing Strategy / State Management]
- Required frontend directory structure: [Source: _bmad-output/planning-artifacts/architecture.md → Project Structure & Boundaries → Complete Project Directory Structure]
- Navigation patterns + bottom tab requirements + touch targets: [Source: _bmad-output/planning-artifacts/ux-design-specification.md → Navigation Patterns; Responsive Design & Accessibility]
- Project-wide agent rules (Riverpod AsyncNotifier, no hardcoded UI values): [Source: _bmad-output/project-context.md]
- Previous story learnings (theme tokens + minimal main): [Source: _bmad-output/implementation-artifacts/1-2-initialize-flutter-mobile-project-with-design-system-foundation.md]

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Debug Log References

- Next backlog story auto-selected from `_bmad-output/implementation-artifacts/sprint-status.yaml` in top-to-bottom order.
- Mobile code inspection: `mobile/lib/` currently contains only `main.dart` + `core/theme/*`.
- Recent git history indicates Story 1.2 and 1.1 are merged into `develop` and establish patterns to follow.
- Red phase validation: `flutter test test/widget_test.dart` failed initially due missing app-shell files (expected).
- Routing fix applied: `StatefulShellBranch` for `/chat/:documentId` now uses `initialLocation: '/chat/active'` to satisfy go_router branch default constraints.
- Validation gates executed: `flutter analyze`, `flutter test test/widget_test.dart`, and full `flutter test` all pass.

### Completion Notes List

- Implemented app shell entrypoint split (`main.dart` + `app.dart`) with `ProviderScope` and `MaterialApp.router` using Story 1.2 themes.
- Implemented go_router configuration in `mobile/lib/router.dart` with required routes, auth redirects, and `StatefulShellRoute.indexedStack` tab branches.
- Implemented `NavigationBar`-based shared scaffold with tokenized colors and 44x44 touch targets in `mobile/lib/shared/widgets/app_scaffold.dart`.
- Added minimal Riverpod async auth state provider (`AuthNotifier`) and debug-build auth toggle via `DOCUMIND_DEBUG_AUTH`.
- Added placeholder screens for login, signup, library, chat (`documentId`), and settings using themed styles and const constructors.
- Added widget tests covering ProviderScope wiring, unauthenticated redirect to `/auth/login`, and tab navigation behavior.

### File List

- _bmad-output/implementation-artifacts/1-3-configure-routing-state-management-and-app-shell.md
- mobile/lib/main.dart
- mobile/lib/app.dart
- mobile/lib/router.dart
- mobile/lib/shared/widgets/app_scaffold.dart
- mobile/lib/features/auth/providers/auth_provider.dart
- mobile/lib/features/auth/screens/login_screen.dart
- mobile/lib/features/auth/screens/signup_screen.dart
- mobile/lib/features/library/screens/library_screen.dart
- mobile/lib/features/chat/screens/chat_screen.dart
- mobile/lib/features/settings/screens/settings_screen.dart
- mobile/test/widget_test.dart

## Change Log

- 2026-03-15: Implemented Story 1.3 app shell, routing, auth guard placeholder, tab scaffold, placeholder screens, and widget test coverage; validated with `flutter analyze` and full `flutter test`.
