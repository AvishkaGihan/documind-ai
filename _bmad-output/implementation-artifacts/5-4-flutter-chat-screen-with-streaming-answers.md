# Story 5.4: Flutter Chat Screen with Streaming Answers

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a mobile user,
I want a polished chat interface where I can ask questions and see answers appear in real-time with citation chips,
so that the Q&A experience feels conversational, trustworthy, and engaging.

## Acceptance Criteria

1. **Given** I open a "ready" document from the Library
   **When** the Chat screen loads
   **Then** I see a chat interface with: the document title in the top bar, previous conversation messages (if any), and a Chat Input Bar anchored at the bottom

2. **Given** I type a question and tap Send
   **When** the question is submitted
   **Then** a User Question Bubble appears in the chat, an AI Typing Indicator (3 pulsing dots with glow) is shown, and the answer begins streaming in an AI Response Bubble character-by-character
   **And** Citation Chips (📄 Page X, purple/lilac accent) appear inline as the answer renders
   **And** the chat auto-scrolls to show the latest content

3. **Given** I tap on a Citation Chip
   **When** the chip is tapped
   **Then** it expands to show the relevant source text excerpt from that page
   **And** tapping again collapses it back

4. **Given** the answer completes streaming
   **When** the `done` event is received
   **Then** the AI Typing Indicator disappears, the full answer with all citations is displayed, and a timestamp is shown

5. **And** the Chat Input Bar auto-expands to max 4 lines, with the Send button disabled when empty
   **And** the keyboard-aware layout prevents content from being obscured by the keyboard
   **And** the interface uses spring-based animations for bubble entry (`Curves.easeOutBack`)

## Tasks / Subtasks

- [x] Resolve "previous conversation messages" loading strategy (AC: 1)
  - [x] **Blocking check:** confirm how the client can discover the active/latest `conversation_id` for a document
    - [x] Current backend endpoints require `conversation_id` to list messages: `GET /api/v1/documents/{document_id}/conversations/{conversation_id}/messages`
    - [x] Backend creates/uses latest conversation on `/ask`, but does not expose `conversation_id` in JSON response or SSE `done` event (only `message_id`)
  - [x] If no active-conversation discovery exists, implement ONE minimal backend-compatible solution (pick the simplest and keep UX unchanged):
    - [x] Option A (recommended, minimal client change): add `GET /api/v1/documents/{document_id}/conversations/latest/messages` returning `MessageListResponse`
    - [x] Option B: include `conversation_id` in `POST /api/v1/documents/{document_id}/ask` responses *(not selected; superseded by Option A)*
      - [x] JSON: add `conversation_id` field to `AskQuestionResponse` *(not implemented by design)*
      - [x] SSE: include `conversation_id` in `event: done` payload *(not implemented by design)*
    - [x] Option C (client-side persistence): persist `conversation_id` per document after first `/ask` and reuse on next load (only acceptable if A/B are rejected) *(not selected; backend Option A implemented)*

- [x] Add chat data + models (supports AC: 1–4)
  - [x] Create a chat API wrapper, consistent with existing patterns in `mobile/lib/features/*/data/*_api.dart`
    - [x] Suggested: `mobile/lib/features/chat/data/chat_api.dart`
    - [x] Methods (exact naming flexible):
      - [x] `Future<DocumentChatBootstrap> bootstrap(documentId)` that returns document title + initial messages (depending on the conversation discovery solution)
      - [x] `Stream<ChatSseEvent> streamAsk({documentId, question})` using `POST /api/v1/documents/{document_id}/ask` with `Accept: text/event-stream`
    - [x] Use existing `dioProvider` for auth + base URL and keep consistent error mapping shape (`detail.code`, `detail.message`, `detail.field`)
  - [x] Define lightweight models (follow existing manual `fromJson` patterns in `document_upload_models.dart`)
    - [x] `ChatMessage` (id optional for in-flight, role, content, citations, createdAt)
    - [x] `Citation` (pageNumber, textExcerpt)
    - [x] `MessageListResponse` mirror of backend (items/total/page/pageSize)
    - [x] `ChatSseEvent` with variants: `token`, `citation`, `done`, `error`

- [x] Implement SSE client parsing and streaming pipeline (AC: 2, 4)
  - [x] Do NOT add new dependencies unless absolutely necessary; prefer `dio` streaming (`ResponseType.stream`) + a small SSE parser
  - [x] SSE format is fixed and must be handled exactly:
    - `event: token` / `data: {"content": "..."}`
    - `event: citation` / `data: {"page": 4, "text": "..."}`
    - `event: done` / `data: {"message_id": "uuid"}`
    - `event: error` / `data: {"code": "LLM_UNAVAILABLE", "message": "..."}`
  - [x] Parsing guidance:
    - [x] Buffer UTF-8 decoded text
    - [x] Split frames by blank line (`\n\n`)
    - [x] Within each frame, extract `event:` and `data:` lines
    - [x] JSON-decode `data:` payload
    - [x] Ignore unknown lines, but never ignore `error`

- [x] Build chat state management with Riverpod (AC: 1–5)
  - [x] Create a controller/provider in `mobile/lib/features/chat/providers/`
    - [x] Use `Notifier` (matches existing controllers like `DocumentUploadController`) OR `AsyncNotifier` if you need an initial async load
    - [x] State should include:
      - [x] document title
      - [x] list of `ChatMessage`
      - [x] input draft text
      - [x] streaming state: isStreaming / inFlightAnswerId
      - [x] citation excerpt map keyed by page number (for chip expansion)
      - [x] UI announcements (for accessibility live regions)
    - [x] Provide actions:
      - [x] `load(documentId)` (bootstrap)
      - [x] `send(question)` that:
        - [x] appends a user message immediately
        - [x] appends an in-flight assistant message placeholder
        - [x] shows typing indicator
        - [x] consumes SSE stream and updates assistant content incrementally
        - [x] accumulates citations as they arrive
        - [x] hides typing indicator on `done`
        - [x] maps `error` to a user-visible error bubble or SnackBar (keep UX simple)

- [x] Implement the Chat UI (AC: 1–5)
  - [x] Update `mobile/lib/features/chat/screens/chat_screen.dart` from placeholder to real UI
    - [x] Top app bar: display the document title (fetch via existing documents API or via bootstrap)
    - [x] Body: message list (use `ListView.builder` + `ScrollController`)
    - [x] Input: bottom-anchored Chat Input Bar (safe-area + keyboard-aware)
  - [x] Create minimal widgets under `mobile/lib/features/chat/widgets/` (no new design system)
    - [x] `chat_input_bar.dart`
      - [x] TextField minLines=1, maxLines=4
      - [x] Send button disabled when trimmed text is empty
    - [x] `user_question_bubble.dart` (distinct styling vs assistant)
    - [x] `ai_response_bubble.dart`
      - [x] Streaming text display (update as tokens arrive)
      - [x] Inline citation chips (render via `TextSpan` + `WidgetSpan` by regex over streamed text OR a segment list)
      - [x] Timestamp displayed when completed
    - [x] `ai_typing_indicator.dart`
      - [x] Three pulsing dots using `tokens.colors.accentAiGlow`
      - [x] Respect Reduce Motion (`MediaQuery.disableAnimations`)
    - [x] `citation_chip.dart`
      - [x] Visual: 📄 + "Page X" with citation accent (`tokens.colors.accentCitation`)
      - [x] Tap toggles expansion showing excerpt text from SSE `citation` payload
      - [x] Semantics label: "Citation page X"
  - [x] Auto-scroll behavior:
    - [x] On new messages and on streaming updates, keep the list pinned to bottom *only if* the user is already near the bottom
    - [x] Avoid fighting user scroll when reading older messages

- [x] Accessibility and UX guardrails (AC: 2–5)
  - [x] Use `Semantics` on:
    - [x] Send button (disabled state announced)
    - [x] Citation chips (button role + expanded/collapsed state)
  - [x] Announce streaming updates thoughtfully (avoid spamming screen readers):
    - [x] Announce "Answer started" when first token arrives
    - [x] Announce "Answer complete" when `done` arrives
  - [x] Ensure 44×44 touch targets for chips and buttons

- [x] Testing (minimum set; keep deterministic)
  - [x] Unit test the SSE parser with a fixed byte stream containing token/citation/done
    - [x] Suggested: `mobile/test/unit/sse_parser_test.dart`
  - [x] Widget tests for chat input + send disabled/enabled behavior
    - [x] Suggested: `mobile/test/widget/chat_input_bar_test.dart`
  - [x] Widget test for basic streaming rendering (fake controller/provider)
    - [x] Suggested: `mobile/test/widget/chat_screen_streaming_test.dart`
    - [x] Guardrail: avoid `pumpAndSettle()` timeouts around TextField/caret + animations; use bounded `pump(const Duration(...))` steps

## Dev Notes

### Developer context (read this first)

This story is the **first real Flutter chat experience**. Backend already supports:
- `POST /api/v1/documents/{document_id}/ask` JSON (Story 5.1)
- `POST /api/v1/documents/{document_id}/ask` SSE streaming (`token`, `citation`, `done`, `error`) (Story 5.2)
- Conversation memory + message listing endpoints (Story 5.3)

The mobile app already has:
- Navigation from Library → Chat via `context.go('/chat/{documentId}')`
- Theme tokens via `DocuMindTokens` and spacing via `AppSpacing`
- Auth via `dioProvider` interceptor (Bearer token from secure storage)

### What already exists (reuse; do not reinvent)

- Route + screen placeholder:
  - `mobile/lib/router.dart` defines `/chat/:documentId`
  - `mobile/lib/features/chat/screens/chat_screen.dart` exists but is placeholder
- Networking stack:
  - `mobile/lib/core/networking/dio_provider.dart` (base URL + auth)
- Document title/status fetching:
  - `mobile/lib/features/library/data/documents_api.dart::getDocumentById`

### Architecture + project guardrails (must follow)

- Use feature-based structure:
  - `mobile/lib/features/chat/data/`
  - `mobile/lib/features/chat/providers/`
  - `mobile/lib/features/chat/screens/`
  - `mobile/lib/features/chat/widgets/`
- Do not hardcode colors/spacing/fonts; use theme tokens and `AppSpacing`
- Use `ListView.builder` for message list
- Keep streaming transport as SSE; do not switch to WebSockets

### Project Structure Notes

- Keep all new chat code scoped to `mobile/lib/features/chat/` (data/providers/models/widgets)
- Prefer the existing repo’s style for models (manual `fromJson`/plain immutable classes) unless you intentionally refactor consistently across the feature
- Avoid touching unrelated features (auth/library/settings) except for wiring minimal shared utilities if absolutely required

### Important dependency / mismatch to resolve

AC #1 requires loading previous messages, but the current backend requires a `conversation_id` to list messages.
- If there is no existing endpoint returning the active/latest `conversation_id`, you must implement one minimal solution (see Tasks) before the Flutter UI can fully satisfy AC #1.

### Error handling scope

Keep error handling minimal and consistent:
- If the backend returns `DOCUMENT_NOT_READY`, show a simple error state and a button to go back to Library.
- If streaming yields `event: error`, show a persistent SnackBar or an inline assistant bubble indicating the failure.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story-5.4:-Flutter-Chat-Screen-with-Streaming-Answers]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Chat-Input-Bar] (auto-expand, keyboard-aware)
- [Source: _bmad-output/project-context.md#API-Response-Formats-(MUST-follow-exactly)] (SSE event names)
- [Source: _bmad-output/implementation-artifacts/5-2-streaming-answer-endpoint-with-sse.md] (SSE payload shapes)
- [Source: _bmad-output/implementation-artifacts/5-3-conversation-memory-and-context-management.md] (message list endpoint)

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex (GitHub Copilot)

### Debug Log References

- Backend red/green cycle: `python -m pytest tests/integration/test_conversation_messages.py -q`
- Mobile focused tests: `flutter test test/unit/sse_parser_test.dart test/widget/chat_input_bar_test.dart test/widget/chat_screen_streaming_test.dart`
- Mobile regression and lint: `flutter analyze`, `flutter test`
- Backend regression: `python -m pytest -q`

### Completion Notes List

- Added backend endpoint `GET /api/v1/documents/{document_id}/conversations/latest/messages` to support chat bootstrap without client-side conversation ID discovery.
- Implemented chat data layer with SSE parsing (`token`, `citation`, `done`, `error`) using `dio` stream transport and no new dependencies.
- Built Riverpod chat controller/state with bootstrap load, incremental streaming updates, citation excerpt tracking, accessibility announcements, and error handling.
- Replaced placeholder chat screen with production UI: keyboard-aware layout, input bar auto-expand (1-4 lines), send disable rules, typing indicator, message bubbles, citation chip expansion, spring bubble entry animations, and near-bottom auto-scroll logic.
- Added deterministic tests for SSE parser, chat input UX, and streaming rendering; updated existing shell navigation test to assert the real chat UI.

### File List

- backend/app/routers/documents.py
- backend/app/services/conversation_service.py
- backend/tests/integration/test_conversation_messages.py
- mobile/lib/features/chat/screens/chat_screen.dart
- mobile/lib/features/chat/data/chat_api.dart
- mobile/lib/features/chat/data/sse_parser.dart
- mobile/lib/features/chat/providers/chat_controller.dart
- mobile/lib/features/chat/models/chat_models.dart
- mobile/lib/features/chat/widgets/chat_input_bar.dart
- mobile/lib/features/chat/widgets/user_question_bubble.dart
- mobile/lib/features/chat/widgets/ai_response_bubble.dart
- mobile/lib/features/chat/widgets/ai_typing_indicator.dart
- mobile/lib/features/chat/widgets/citation_chip.dart
- mobile/test/unit/sse_parser_test.dart
- mobile/test/widget/chat_input_bar_test.dart
- mobile/test/widget/chat_screen_streaming_test.dart
- mobile/test/widget_test.dart

## Change Log

- 2026-03-20: Implemented Story 5.4 chat streaming experience end-to-end, including backend latest conversation bootstrap endpoint, mobile chat UI/controller/data pipeline, and full validation (backend + mobile tests, Flutter analyze).
