# Story 6.5: Accessibility Compliance and Screen Reader Support

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user with accessibility needs,
I want the app to fully support screen readers, text scaling, and keyboard navigation,
so that I can use DocuMind AI regardless of my abilities.

## Acceptance Criteria

1. **Given** I am using VoiceOver (iOS) or TalkBack (Android)
   **When** I navigate through the app
   **Then** all interactive elements have semantic labels (e.g., Send button: "Send question", Citation Chip: "Page reference, page 12. Tap to view source.")
   **And** AI streaming responses are announced as live regions (accumulated and announced every sentence)
   **And** document status changes are announced (e.g., "Document Contract Review is now ready")

2. **Given** I have increased my system font size to 200%
   **When** I use the app
   **Then** all text scales appropriately, layouts adapt without clipping or overlap, and the app remains fully functional

3. **Given** I have enabled "Reduce Motion" in system settings
   **When** I use the app
   **Then** all spring-based animations, pulsing indicators, and parallax effects are replaced with static or minimal-motion alternatives

4. **Given** I am navigating via keyboard or switch control
   **When** I tab through interactive elements
   **Then** visible focus indicators (accent-colored rings) are shown on the focused element
   **And** all interactive elements are reachable and operable

5. **And** all text/background color combinations meet WCAG 2.1 AA contrast ratio (4.5:1 for normal text, 3:1 for large text)

6. **And** all touch targets are at minimum 44×44pt

7. **And** icon-only buttons have tooltips on long-press

## Tasks / Subtasks

- [x] Mobile: Screen reader semantics audit + fixes (AC: 1, 7)
  - [x] Audit all primary flows for missing labels: Auth, Library, Upload, Chat, Conversation management
  - [x] Ensure every `IconButton`/icon-only interactive control has a `tooltip` (long-press on mobile)
  - [x] Ensure interactive wrappers use correct semantics roles (`button`, `toggled`, `enabled`, etc.)
  - [x] Ensure decorative icons/images are excluded (`ExcludeSemantics`) to avoid noisy announcements
  - [x] Tighten wording to match UX examples exactly where specified:
    - [x] Send button label: "Send question" (not "Send message")
    - [x] Citation chips: "Page reference, page X. Tap to view source." (include expand/collapse state)

- [x] Mobile: Live-region announcements for streaming answers (AC: 1)
  - [x] Implement sentence-based announcement buffering during SSE streaming:
    - [x] Accumulate tokens into an announcement buffer
    - [x] Detect sentence boundaries (`.`, `?`, `!`, including common edge cases like abbreviations) and announce completed sentences
    - [x] Rate-limit announcements to avoid overwhelming screen readers (but still meet “every sentence” requirement)
  - [x] Keep existing non-a11y behavior unchanged (visual streaming, citations, error handling)
  - [x] Ensure announcements respect current text direction and do not spam duplicates

- [x] Mobile: Document status change announcements (AC: 1)
  - [x] Announce meaningful transitions including document title (e.g., "Document <title> is now ready")
  - [x] Cover:
    - [x] Upload pipeline polling transitions (existing upload card polling)
    - [x] Library list refresh transitions (documents that finish processing outside the upload flow)

- [x] Mobile: Text scaling @ 200% without layout breakage (AC: 2)
  - [x] Audit and fix overflow/clipping on smallest width (320px) with `textScaleFactor: 2.0`
  - [x] Prefer flexible layout fixes over truncation; use wrapping where appropriate
  - [x] Ensure tap targets and layout remain usable (no overlapped controls)

- [x] Mobile: Reduce Motion parity across the app (AC: 3)
  - [x] Inventory all animations used in Chat/Library (typing indicator, shimmer, processing indicator, any transitions)
  - [x] Ensure all animated affordances gate on `MediaQuery.disableAnimations`
  - [x] Verify minimal-motion or static alternatives exist for all pulsing/spring-like effects

- [x] Mobile: Keyboard / switch navigation + focus rings (AC: 4)
  - [x] Ensure tab traversal reaches all interactive elements in Library and Chat
  - [x] Implement a consistent accent-colored focus ring for key controls (buttons, chips, document cards)
  - [x] Ensure focus order is logical (top-to-bottom, left-to-right)

- [x] Accessibility validation: contrast + touch targets (AC: 5, 6)
  - [x] Verify theme tokens meet WCAG 2.1 AA contrast requirements (no new colors introduced)
  - [x] Verify interactive elements meet 44×44pt minimum touch target (chips, icon buttons, cards)

- [x] Tests (deterministic; avoid `pumpAndSettle()` timeouts) (AC: 1–7)
  - [x] Widget test: Semantics labels present for critical controls
    - [x] Send button label == "Send question"
    - [x] Citation chip label matches UX copy
    - [x] Upload / new conversation buttons have tooltips
  - [x] Widget test: Streaming announcements emit per sentence (assert announcement state changes / semantics events proxy)
  - [x] Widget test: Text scaling at 200% doesn’t overflow (pump key screens with `MediaQuery(textScaleFactor: 2.0)`)
  - [x] Widget test: Reduce Motion renders static variants (pump with `disableAnimations: true`)
  - [x] Widget test: Keyboard tab focus shows focus ring on focused control (smoke-level; keep stable)

## Dev Notes

### Developer Context (reuse-first)

The codebase already has several accessibility hooks — extend them instead of inventing new patterns:

- Announcements already flow through state and are emitted via `SemanticsService.sendAnnouncement`:
  - `mobile/lib/features/chat/screens/chat_screen.dart` listens to `ChatState.announcement`
  - `mobile/lib/features/library/screens/library_screen.dart` listens to `DocumentUploadState.announcement`
- Reduce Motion is already implemented in multiple shared widgets via `MediaQuery.disableAnimations`:
  - `mobile/lib/shared/widgets/loading_shimmer.dart`
  - `mobile/lib/features/library/widgets/processing_animation.dart`
  - `mobile/lib/features/chat/widgets/ai_typing_indicator.dart`

### Technical Requirements / Guardrails

- Do not add new screens/routes; changes are enhancements to existing widgets and providers.
- Use theme tokens only (`DocuMindTokens`, `AppSpacing`); do not hardcode colors/spacing.
- Keep state changes inside Riverpod providers/controllers; keep widgets presentational.
- Keep announcements user-friendly and low-noise:
  - Prefer announcing “meaningful” state transitions (ready/error) over every polling tick.
  - For streaming answers, announce only completed sentences.

### Architecture Compliance

- Follow Flutter rules from `_bmad-output/project-context.md`:
  - Riverpod `AsyncNotifier`/`Notifier` for async state
  - tokenized theming only
  - deterministic widget tests; avoid flaky `pumpAndSettle()` patterns

### Library / Framework Requirements

- Flutter Semantics:
  - Prefer `Semantics(button: true, label: ...)` for custom tap targets.
  - Use `ExcludeSemantics` for decorative visuals.
  - Continue using `SemanticsService.sendAnnouncement(View.of(context), text, Directionality.of(context))` for explicit announcements.
- Tooltips:
  - For icon-only controls, set `tooltip:` (IconButton already supports long-press tooltip on mobile).

### File Structure Requirements (expected touchpoints)

- Chat accessibility
  - `mobile/lib/features/chat/providers/chat_controller.dart` (sentence announcement buffering)
  - `mobile/lib/features/chat/screens/chat_screen.dart` (ensure announcement emission stays correct)
  - `mobile/lib/features/chat/widgets/chat_input_bar.dart` (send semantics label + tooltip)
  - `mobile/lib/features/chat/widgets/citation_chip.dart` (label text + toggled state)
  - `mobile/lib/features/chat/widgets/ai_response_bubble.dart` (ensure semantics for response content/citations)

- Library accessibility
  - `mobile/lib/features/library/screens/library_screen.dart` (icon button tooltips + any missing semantics wrappers)
  - `mobile/lib/features/library/providers/document_list_provider.dart` (announce status changes in list refresh)
  - `mobile/lib/features/library/providers/document_upload_controller.dart` (include title in status announcements)
  - `mobile/lib/features/library/widgets/document_card.dart` (ensure label is complete and tap target semantics remain correct)

- Shared accessibility primitives (only if needed)
  - `mobile/lib/shared/widgets/` (a small focus-ring helper is acceptable if it avoids duplicating decoration logic)

### Testing Requirements

- Prefer `SemanticsTester` in Flutter widget tests to assert labels/roles/toggled state.
- Keep routing/tests bounded and deterministic (avoid `pumpAndSettle()` timeouts; use small fixed `pump(Duration(...))` steps).
- Include at least one smoke test for `textScaleFactor: 2.0` on both Library and Chat.

### Previous Story Intelligence (from 6.4 / 6.3)

- Existing snackbar + warning/error patterns are centralized in `mobile/lib/shared/widgets/app_snackbar.dart` (do not diverge).
- Reduce-motion behavior is already established via `MediaQuery.disableAnimations` (follow the same gating everywhere).
- Widget tests can become flaky with animations/caret; use bounded pumps and avoid `pumpAndSettle()`.

### Git Intelligence Summary

Recent commits show epic-6 work is mobile-heavy and test-driven:
- `a059f26` / PR #29 (Story 6.4) standardized feedback + added deterministic tests
- `07b4620` / PR #28 (Story 6.3) implemented reduce-motion-safe loading/processing UI

### References

- Story definition + acceptance criteria:
  - `_bmad-output/planning-artifacts/epics.md` → "Epic 6" → "Story 6.5: Accessibility Compliance and Screen Reader Support"

- UX accessibility requirements + testing guidance:
  - `_bmad-output/planning-artifacts/ux-design-specification.md` → "Responsive Design & Accessibility" → "Accessibility Strategy" and "Accessibility Testing"

- Architecture NFRs + tech stack constraints:
  - `_bmad-output/planning-artifacts/architecture.md` → "Requirements Overview" → NFR table (Accessibility)

- Project-wide implementation guardrails:
  - `_bmad-output/project-context.md` → "Critical Implementation Rules" → "Flutter (Frontend)" + "Testing Rules" + "Anti-Patterns"

- Prior epic-6 learnings:
  - `_bmad-output/implementation-artifacts/6-4-comprehensive-error-handling-and-system-feedback.md`
  - `_bmad-output/implementation-artifacts/6-3-loading-states-and-processing-feedback.md`

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Debug Log References

- `flutter analyze` (no issues)
- `flutter test` (full suite, 55 tests passed)
- Targeted accessibility regression set:
  - `test/unit/chat_controller_test.dart`
  - `test/unit/document_list_provider_test.dart`
  - `test/widget/chat_input_bar_test.dart`
  - `test/widget/chat_screen_streaming_test.dart`
  - `test/widget/library_screen_document_list_test.dart`

### Completion Notes List

- Implemented sentence-buffered, rate-limited live-region announcements for streaming chat responses with abbreviation/decimal/ellipsis boundary guards and duplicate suppression.
- Updated semantics and tooltips for icon-only/interactive controls, including exact UX copy for send and citation labels.
- Added document-title-aware status announcements in upload polling and document list refresh flows.
- Added shared `AccessibilityFocusRing` primitive and applied it to key controls in Chat/Library for keyboard/switch discoverability.
- Added deterministic widget/unit tests for semantics copy, tooltip exposure, text scaling at 200%, reduce-motion behavior, and streaming announcement behavior.
- Validated all mobile quality gates: static analysis clean and full test suite passing.

### File List

- _bmad-output/implementation-artifacts/6-5-accessibility-compliance-and-screen-reader-support.md
- mobile/lib/shared/widgets/accessibility_focus_ring.dart
- mobile/lib/features/chat/providers/chat_controller.dart
- mobile/lib/features/chat/screens/chat_screen.dart
- mobile/lib/features/chat/widgets/chat_input_bar.dart
- mobile/lib/features/chat/widgets/citation_chip.dart
- mobile/lib/features/library/providers/document_list_provider.dart
- mobile/lib/features/library/providers/document_upload_controller.dart
- mobile/lib/features/library/screens/library_screen.dart
- mobile/lib/features/library/widgets/document_card.dart
- mobile/test/unit/chat_controller_test.dart
- mobile/test/unit/document_list_provider_test.dart
- mobile/test/unit/document_upload_controller_test.dart
- mobile/test/widget/chat_input_bar_test.dart
- mobile/test/widget/chat_screen_streaming_test.dart
- mobile/test/widget/library_screen_document_list_test.dart

## Change Log

- 2026-03-21: Created Story 6.5 context file with concrete accessibility implementation guardrails and test guidance.
- 2026-03-21: Implemented Story 6.5 accessibility features (semantics/tooltips, live announcements, focus rings, status announcements), added deterministic tests, passed `flutter analyze` and full `flutter test`.
