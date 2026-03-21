# Story 2.6: Auth Screens Visual Polish & Branding

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a mobile user,
I want to see beautiful, branded login and signup screens with rich aesthetics,
so that my first impression of the app is premium and trustworthy.

## Acceptance Criteria

1. **Given** I am on the Login or Signup screen
   **When** I view the background and form
   **Then** I see the DocuMind AI Logo/Branding element at the top

2. **And** the background uses a subtle glassmorphic effect or gradient aligned with the "Hybrid Premium" theme

3. **And** input fields use custom borders and focus rings matching the accent color

4. **And** login buttons use the full-width Primary style with rich hover/press states

## Tasks / Subtasks

- [x] Introduce a branded auth screen shell to avoid duplication (AC: 1–4)
  - [x] Create a small auth-only wrapper widget (e.g., `mobile/lib/features/auth/widgets/auth_branded_scaffold.dart`) that:
    - [x] Renders a background layer (gradient and/or subtle glow) using existing theme tokens only
    - [x] Provides a centered, constrained content area (match current `maxWidth: 420` pattern)
    - [x] Supports keyboard-safe scrolling (`SingleChildScrollView`) without layout jank
    - [x] Exposes a slot for the form content used by both Login and Signup

- [x] Add a DocuMind AI branding element at the top (AC: 1)
  - [x] Implement a wordmark-style header (preferred for MVP):
    - [x] Text-based "DocuMind AI" (or "DocuMind") using `Theme.of(context).textTheme` and `DocuMindTokens` colors
    - [x] Optional small subtitle/tagline (token-colored) if it does not increase vertical clutter
  - [x] Keep it accessible:
    - [x] Add a stable semantics label / text so widget tests can assert it
    - [x] Ensure it remains visible on small screens with keyboard open

- [x] Implement "Hybrid Premium" background treatment (AC: 2)
  - [x] Use *only* existing palette colors from `DocuMindTokens` (no new hard-coded hex colors)
  - [x] Choose ONE simple approach (prefer simplest that meets AC):
    - [x] **Gradient**: a subtle `LinearGradient` mixing `tokens.colors.surfacePrimary` with low-opacity accents derived from `tokens.colors.accentPrimary` / `tokens.colors.accentCitation`
    - [x] **Glassmorphic form container**: a frosted container behind the form using `BackdropFilter` + translucent fill derived from existing tokens
  - [x] Ensure the background does not reduce text contrast (WCAG AA intent) and does not cause performance issues (avoid expensive blurs on every frame)

- [x] Upgrade input field borders + focus affordances to match accent (AC: 3)
  - [x] Do not break global input styling unless deliberately chosen:
    - [x] Preferred: auth-screen-only `InputDecoration` overrides (keep the rest of the app stable)
    - [x] Acceptable: adjust global `inputDecorationTheme.focusedBorder` if consistent with the overall design direction—verify chat/library visuals remain acceptable
  - [x] Use accent color for focused state:
    - [x] `focusedBorder` and/or focus ring uses `tokens.colors.accentPrimary`
    - [x] Consider wrapping fields with the existing `AccessibilityFocusRing` widget for keyboard/switch navigation affordance

- [x] Ensure primary buttons have rich press/hover states and remain full-width (AC: 4)
  - [x] Keep current sizing constraints:
    - [x] Full width and minimum height 44
  - [x] Add stateful styling using `MaterialStateProperty`:
    - [x] Press/hover overlay derived from `tokens.colors.accentPrimary.withOpacity(...)`
    - [x] Optional subtle elevation/brightness change on press (no new shadows/colors)
  - [x] Ensure loading states remain correct and readable on dark background

- [x] Apply the new shell consistently to both login and signup screens (AC: 1–4)
  - [x] Refactor `LoginScreen` and `SignupScreen` to share the shell without changing auth logic
  - [x] Preserve existing widget keys used in tests:
    - [x] `login-email-field`, `login-password-field`, `login-submit-button`
    - [x] `signup-email-field`, `signup-password-field`, `signup-submit-button`

- [x] Update / add widget tests for brand element presence and key stability (AC: 1)
  - [x] Add a test asserting the branding element renders on `/auth/login`
  - [x] Add a test asserting the branding element renders on `/auth/signup`
  - [x] Avoid `pumpAndSettle()` if animations/indicators are introduced; use bounded `pump(Duration(...))` loops (see existing `pumpFrames` pattern)

## Dev Notes

### What already exists (reuse; do not reinvent)

- Auth screens already exist and meet functional AC from Story 2.5:
  - `mobile/lib/features/auth/screens/login_screen.dart`
  - `mobile/lib/features/auth/screens/signup_screen.dart`
- Design tokens + theme system already exist and must be used (no hardcoded colors/spacing):
  - `mobile/lib/core/theme/app_theme.dart`
  - `mobile/lib/core/theme/app_colors.dart`
  - `mobile/lib/core/theme/theme_extensions.dart` (`DocuMindTokens`)
  - `mobile/lib/core/theme/app_spacing.dart`
- Accessibility focus helper exists:
  - `mobile/lib/shared/widgets/accessibility_focus_ring.dart`

### Design intent ("Hybrid Premium")

- Dark mode default with glassmorphism accents and a vibrant-but-controlled palette.
- Glassmorphism should be subtle and premium (avoid heavy blur + high opacity that harms readability).
- Accent colors:
  - Primary accent = `tokens.colors.accentPrimary`
  - Citation accent (purple) = `tokens.colors.accentCitation`

### Guardrails (avoid regressions)

- Do not change route paths or auth flows; visuals only.
- Do not add new color hex values; derive all visuals from `DocuMindTokens`.
- Keep 44×44pt touch targets for buttons and links.
- Preserve the existing widget keys and inline validation/error placement behavior.
- Avoid heavy animations or long-running effects that could destabilize widget tests.

### Testing standards

- Update `mobile/test/widget_test.dart` as needed.
- Prefer deterministic, bounded pumping (e.g., the existing `pumpFrames()` helper) over `pumpAndSettle()`.

### Project Structure Notes

- Keep changes scoped to auth UI (visuals only):
  - Screens: `mobile/lib/features/auth/screens/`
  - Small shared auth-only widgets (if needed): `mobile/lib/features/auth/widgets/`
- Avoid introducing a second global theming system; prefer leveraging `DocuMindTokens` + existing `ThemeData`.

### Git Intelligence Summary

- Recent commit context suggests Story 2.6 was introduced alongside Epic 7 planning and a sprint change proposal.
- A recent backend streaming fix landed (`anyio.fail_after` removal); unrelated, but indicates current work focuses on stability—keep this story purely visual to avoid cross-cutting regressions.

### References

- Epic requirements: `_bmad-output/planning-artifacts/epics.md` → “Story 2.6: Auth Screens Visual Polish & Branding”
- Existing auth screen implementation patterns + key stability: `_bmad-output/implementation-artifacts/2-5-flutter-authentication-screens-and-token-management.md`
- UX direction chosen: `_bmad-output/planning-artifacts/ux-design-specification.md` → “Design Direction Decision” → “Direction 6: Hybrid Premium”
- Theme tokens and palette (source of truth): `mobile/lib/core/theme/app_colors.dart`, `mobile/lib/core/theme/app_theme.dart`
- Accessibility focus ring helper: `mobile/lib/shared/widgets/accessibility_focus_ring.dart`

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Debug Log References

- `flutter test test/widget_test.dart` (red phase: failing brand tests before implementation)
- `flutter analyze` (no issues)
- `flutter test test/widget_test.dart` (green phase: brand tests passing)
- `flutter test` (full regression suite passing)

### Completion Notes List

- Implemented `AuthBrandedScaffold` to centralize auth page layout, background treatment, and brand header.
- Added top-of-screen DocuMind branding with stable visible text (`DocuMind AI`) and semantics label for accessibility.
- Applied auth-only text field styling with accent-focused borders and `AccessibilityFocusRing` wrappers.
- Added richer primary button hover/press/focus state styling while preserving full-width 44pt controls and existing loading behavior.
- Refactored `LoginScreen` and `SignupScreen` to use the shared shell without changing auth flows, routes, or key identifiers.
- Added widget tests for branding presence on `/auth/login` and `/auth/signup` using bounded frame pumping.

### File List

- `mobile/lib/features/auth/widgets/auth_branded_scaffold.dart` (new)
- `mobile/lib/features/auth/screens/login_screen.dart` (updated)
- `mobile/lib/features/auth/screens/signup_screen.dart` (updated)
- `mobile/test/widget_test.dart` (updated)

### Change Log

- 2026-03-21: Implemented Story 2.6 auth visual polish and branding updates; all mobile tests and analysis passed.
