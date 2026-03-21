# Story 6.4: Comprehensive Error Handling and System Feedback

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a mobile user,
I want to see clear, actionable error messages for all failure scenarios,
so that I understand what went wrong and how to fix it.

## Acceptance Criteria

1. **Given** a document processing fails (unsupported format, corrupted file, excessive size)
   **When** the error is detected
   **Then** a red SnackBar with error icon appears (persistent until dismissed) with a specific message (e.g., "This file isn't a valid PDF. Please upload a PDF file.") and a "Retry" action where applicable

2. **Given** the AI cannot answer a question from the document content
   **When** the system determines no relevant chunks exist
   **Then** the AI Response Bubble shows: "I couldn't find relevant information for this question in the document. Try rephrasing your question or asking about a different topic."

3. **Given** the Groq API rate limit is reached
   **When** a 429 response is received
   **Then** an amber warning SnackBar shows: "You've reached the query limit. Please wait [X] seconds." with a countdown or estimated wait time
   **And** the chat input is temporarily disabled until the rate limit resets

4. **Given** a network error occurs during any API call
   **When** the request fails
   **Then** an appropriate error message is shown with a "Retry" action

5. **And** all error responses from the backend use the consistent format: `{"detail": {"code": "ERROR_CODE", "message": "Human-readable message"}}`

## Tasks / Subtasks

- [x] Mobile: standardize SnackBar feedback primitives (AC: 1, 3, 4)
  - [x] Reuse existing pattern in `mobile/lib/features/library/screens/library_screen.dart` (persistent error snackbar + retry) as the baseline
  - [x] Implement a minimal shared helper (preferred) at `mobile/lib/shared/widgets/app_snackbar.dart` with:
    - [x] `showPersistentErrorSnackBar(context, tokens, message, {onRetry})` → red background (`tokens.colors.accentError`), error icon in content, duration `Duration(days: 1)`, optional `SnackBarAction(label: 'Retry')`
    - [x] `showWarningSnackBar(context, tokens, message)` → amber background (`tokens.colors.accentWarning`), warning icon in content, duration `Duration(seconds: 5)`
  - [x] Update call sites to use helper (no extra UI variants):
    - [x] `mobile/lib/features/chat/screens/chat_screen.dart` (currently shows red snackbar without icon/action)
    - [x] `mobile/lib/features/library/screens/library_screen.dart` (keep behavior; add icon to match UX)

- [x] Mobile: document processing failure feedback (AC: 1)
  - [x] Show persistent red SnackBar on **processing failures**, not only upload failures:
    - [x] Extend the existing `ref.listen<DocumentUploadState>` in `mobile/lib/features/library/screens/library_screen.dart` to also trigger on transition into `UploadCardPhase.processingError`
    - [x] Message source order: `next.uploadedDocument?.errorMessage` → fallback string
    - [x] Provide Retry action where applicable (use existing `DocumentUploadController.retryUpload()`)
  - [x] Ensure messages are specific and user-friendly:
    - [x] If backend returns generic extraction errors (e.g., "Failed to extract text from PDF"), map to a user-facing string consistent with the AC example

- [x] Backend: unanswerable question message must match UX copy (AC: 2)
  - [x] Update `backend/app/services/rag_service.py` so the "no relevant chunks" fallback matches **exactly**:
    - [x] "I couldn't find relevant information for this question in the document. Try rephrasing your question or asking about a different topic."
  - [x] Apply consistently to both:
    - [x] Non-streaming `ask_question()` (returns `AskQuestionResponse`)
    - [x] Streaming `stream_answer_events()` (currently yields the shorter fallback string as tokens)
  - [x] Keep the existing behavior: no citations when unanswerable

- [x] Backend: Groq rate limit → HTTP 429 with wait time and consistent error payload (AC: 3, 5)
  - [x] Detect rate limiting from the Groq/LangChain stack inside `backend/app/services/llm_service.py`:
    - [x] Introduce a dedicated exception type (e.g., `LlmRateLimitError(retry_after_seconds: int | None)`)
    - [x] When the upstream error indicates 429/rate-limit, raise `LlmRateLimitError` instead of the generic `LlmServiceError`
  - [x] Ensure the streaming ask endpoint returns an actual 429 response (not only an SSE `error` event):
    - [x] Update `backend/app/services/rag_service.py` to let `LlmRateLimitError` propagate (or wrap into a typed `RagServiceRateLimitError`)
    - [x] Update `backend/app/routers/documents.py` `/ask` handler to catch and raise `HTTPException(status_code=429, detail=build_error_detail(code='RATE_LIMITED', message='...'))`
    - [x] Message must follow AC copy and include an estimated wait time: "You've reached the query limit. Please wait [X] seconds."
    - [x] Include `Retry-After` response header if `retry_after_seconds` is known (preferred) so mobile can compute [X] reliably

- [x] Mobile: 429 UX (amber snackbar + disable input until reset) (AC: 3)
  - [x] Extend `ChatApiError` in `mobile/lib/features/chat/data/chat_api.dart` to carry optional retry timing (e.g., `retryAfterSeconds` and/or `rateLimitResetAt`)
  - [x] In `ChatApi._mapError(DioException error)`:
    - [x] Special-case `error.response?.statusCode == 429` and parse timing from headers (`Retry-After` preferred; optionally `X-RateLimit-Reset` if present)
    - [x] Return `ChatApiError(code: 'RATE_LIMITED', message: detail.message, retryAfterSeconds: parsed)`
  - [x] Update `ChatController` (`mobile/lib/features/chat/providers/chat_controller.dart`) to:
    - [x] Track a rate-limit "cooldown" end time in state (new fields) and block sends while active
    - [x] Trigger an **amber** snackbar message with [X] seconds when receiving `RATE_LIMITED`
    - [x] Re-enable input automatically when cooldown expires
  - [x] Update `ChatInputBar` (`mobile/lib/features/chat/widgets/chat_input_bar.dart`) to support disabling:
    - [x] Add `enabled` (or `isDisabled`) parameter; set `TextField.enabled = false` during rate-limit cooldown
    - [x] Ensure send button disabled as well

- [x] Mobile: network error retry affordances (AC: 4)
  - [x] Ensure any snackbar-based error feedback includes a Retry action when the operation can be repeated safely:
    - [x] Upload already supports retry via `DocumentUploadController.retryUpload()`
    - [x] Document list already supports retry via `DocumentListNotifier.refresh()` (keep existing UI button)
    - [x] For chat send failures, add a safe retry path that does **not** duplicate the user message:
      - [x] Prefer tracking the last failed question + in-flight assistant message id in `ChatController`, and retry only the streaming request

- [x] Tests (deterministic; avoid `pumpAndSettle()` timeouts) (AC: 1–5)
  - [x] Backend unit tests:
    - [x] Update `backend/tests/unit/test_rag_service.py` and/or `backend/tests/unit/test_rag_service_streaming.py` to assert the full unanswerable message is returned/yielded
    - [x] Add a focused test for 429 mapping that simulates a Groq rate-limit exception and verifies `HTTP 429` with `detail.code == 'RATE_LIMITED'` and a wait-time message
  - [x] Mobile widget tests:
    - [x] Extend `mobile/test/widget/library_screen_upload_test.dart` to assert a persistent error snackbar appears on processing error transition (and includes Retry)
    - [x] Extend `mobile/test/widget/chat_screen_streaming_test.dart` (or add a focused new test) to assert:
      - [x] Receiving a 429 causes an amber snackbar
      - [x] Chat input is disabled until cooldown expires
    - [x] Extend `mobile/test/widget/chat_input_bar_test.dart` to cover the new disabled state (TextField + send button)

## Dev Notes

### Ground Truth: current implementation touchpoints (reuse-first)

**Mobile networking**
- `mobile/lib/core/networking/dio_provider.dart`
  - Adds auth header and FormData content-type removal via interceptor.
  - Does **not** implement global error mapping; each API maps errors locally.

**Mobile per-feature error mapping**
- `mobile/lib/features/chat/data/chat_api.dart` → `_mapError(DioException)` parses `response.data.detail.{code,message,field}` else returns `NETWORK_ERROR`
- `mobile/lib/features/library/data/documents_api.dart` and `mobile/lib/features/auth/data/auth_api.dart` use similar patterns (mirror the chat mapping approach)

**Current SnackBar usage**
- `mobile/lib/features/library/screens/library_screen.dart`
  - Shows persistent red SnackBar with Retry for **upload** failures.
- `mobile/lib/features/chat/screens/chat_screen.dart`
  - Shows persistent red SnackBar for `chatState.errorMessage`, but **no icon** and **no retry action**.

**Processing errors**
- Backend sets `DocumentStatus.ERROR` + `error_message` in `backend/app/services/processing/pipeline.py`.
- Mobile upload polling maps backend `status == 'error'` → `UploadCardPhase.processingError` in `mobile/lib/features/library/providers/document_upload_controller.dart`.
- UI currently shows inline error text + Retry button in `mobile/lib/features/library/widgets/document_upload_card.dart`, but **does not** pop the required SnackBar.

### Backend error payload contract (must not regress)

- Backend standardizes error details via `backend/app/routers/errors.py` (`build_error_detail`).
- Request validation is already normalized in `backend/app/main.py` (422 with `detail.code = VALIDATION_ERROR`).
- All new 429 logic must use `build_error_detail(...)` so mobile parsing continues to work.
- Note: `build_error_detail(...)` currently includes a nullable `field` key. Even though the epic AC example omits it, keep returning `detail.code` + `detail.message` consistently and do not break existing clients that may read `detail.field`.

### Rate limit guidance (pragmatic, testable)

- This codebase does not currently implement `slowapi` middleware, so do **not** assume `X-RateLimit-*` headers already exist.
- Prefer implementing `Retry-After` on 429 responses for mobile UX; optionally add `X-RateLimit-Reset` later if/when a true limiter is introduced.

### Git intelligence (recent patterns to mirror)

- Recent epic-6 work is mobile-heavy and test-driven:
  - Merge commit for Story 6.3: `07b4620` (loading states + processing feedback)
  - Merge commit for Story 6.2: `e0316b0` (offline caching + queuing)
- Keep new widget tests bounded and deterministic (avoid `pumpAndSettle()` timeouts).

### Project Structure Notes

- Shared UI primitives belong under `mobile/lib/shared/widgets/` (existing: `app_scaffold.dart`, `loading_shimmer.dart`).
- Backend must keep "routers thin" and push parsing/classification into `app/services/*`.

### References

- Story definition + AC:
  - `_bmad-output/planning-artifacts/epics.md` → "Epic 6" → "Story 6.4: Comprehensive Error Handling and System Feedback"

- UX feedback treatment rules:
  - `_bmad-output/planning-artifacts/ux-design-specification.md` → "Feedback Patterns" table

- Backend error contract + rate limit strategy (target architecture):
  - `_bmad-output/planning-artifacts/architecture.md` → "Error Handling Standards" + "Rate Limiting Strategy"

- Implementation guardrails:
  - `_bmad-output/project-context.md` → "API Response Formats" + "Anti-Patterns to AVOID"

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Debug Log References

- Backend targeted tests: `python -m pytest tests/unit/test_rag_service.py tests/unit/test_rag_service_streaming.py tests/integration/test_documents_ask_streaming.py` (9 passed)
- Backend full regression: `python -m pytest` (86 passed)
- Mobile targeted widgets: `flutter test test/widget/library_screen_upload_test.dart test/widget/chat_screen_streaming_test.dart test/widget/chat_input_bar_test.dart` (10 passed)
- Mobile full regression: `flutter test` (47 passed)
- Mobile static analysis: `flutter analyze` (no issues)

### Completion Notes List

- Added shared snackbar primitives (`showPersistentErrorSnackBar`, `showWarningSnackBar`) and migrated chat/library usage to unified icon+color behavior.
- Extended library upload-state listener to show persistent processing-error snackbars with retry and user-friendly extraction-failure mapping.
- Updated RAG unanswerable fallback copy (non-streaming + streaming) to exact UX text while preserving no-citation behavior.
- Added typed rate-limit propagation (`LlmRateLimitError` -> `RagServiceRateLimitError`) and mapped `/ask` to real HTTP 429 with consistent `detail.code/detail.message` and `Retry-After` when available.
- Extended mobile chat API/controller/input for 429 cooldown UX: parse retry timing, show amber warning snackbar, block sends during cooldown, and auto-re-enable input.
- Added safe chat retry flow for send failures via `ChatController.retryLastFailedSend()` without duplicating user messages.
- Added/updated backend and mobile tests for unanswerable-copy, 429 behavior, processing-error snackbar, cooldown disabling, and input disabled state.

### File List

- backend/app/routers/documents.py
- backend/app/services/llm_service.py
- backend/app/services/rag_service.py
- backend/tests/integration/test_documents_ask_streaming.py
- backend/tests/unit/test_rag_service.py
- backend/tests/unit/test_rag_service_streaming.py
- mobile/lib/features/chat/data/chat_api.dart
- mobile/lib/features/chat/providers/chat_controller.dart
- mobile/lib/features/chat/screens/chat_screen.dart
- mobile/lib/features/chat/widgets/chat_input_bar.dart
- mobile/lib/features/library/screens/library_screen.dart
- mobile/lib/shared/widgets/app_snackbar.dart
- mobile/test/widget/chat_input_bar_test.dart
- mobile/test/widget/chat_screen_streaming_test.dart
- mobile/test/widget/library_screen_upload_test.dart

## Change Log

- 2026-03-21: Implemented comprehensive error-handling UX for Story 6.4 across backend and mobile, including typed 429 propagation, cooldown-aware chat input behavior, and deterministic widget/integration coverage.
