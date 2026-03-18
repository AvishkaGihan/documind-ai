# Story 3.1: PDF Upload API and Cloud Storage

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user,
I want to upload a PDF file from my phone to the cloud,
so that the system can store and process it for Q&A.

## Acceptance Criteria

1. **Given** I am an authenticated user
   **When** I send a multipart POST request to `/api/v1/documents/upload` with a PDF file (≤50 MB)
   **Then** the file is uploaded to S3/Cloudinary with the user's account association
   **And** a new Document record is created with status `processing`, title extracted from filename, file_size, and file_path
   **And** the response returns the document id, title, status, and created_at

2. **Given** I upload a file that is not a genuine PDF (wrong magic bytes or extension)
   **When** the server validates the file
   **Then** a 422 error is returned with `detail.code: "INVALID_FILE_TYPE"` and `detail.message: "Only PDF files are supported"`

3. **Given** I upload a file larger than 50 MB
   **When** the server validates the file
   **Then** a 413 error is returned with `detail.code: "FILE_TOO_LARGE"`

## Tasks / Subtasks

- [x] Add documents upload endpoint wiring (AC: 1–3)
  - [x] Create `app/routers/documents.py` with `POST /upload`
  - [x] Mount router under `/api/v1/documents` in `app/main.py`
  - [x] Require auth via `CurrentUser` dependency (`app/dependencies/auth.py`)

- [x] Define request/response schemas for upload response (AC: 1)
  - [x] Create `app/schemas/documents.py` (or `app/schemas/document.py`) with Pydantic v2 models:
    - [x] `DocumentPublic { id: UUID4, title: str, status: DocumentStatus, created_at: datetime }`
  - [x] Ensure response fields are `snake_case` and IDs are returned as UUID strings

- [x] Implement `DocumentService` orchestrating validation → storage → DB record (AC: 1–3)
  - [x] Create `app/services/document_service.py`
  - [x] Add size validation (≤ 50 MB) that works even if `Content-Length` is missing
  - [x] Add PDF validation: check magic bytes `%PDF-` (do not rely on extension or content-type)
  - [x] Translate domain errors into router HTTP errors using standard error payload format

- [x] Implement storage abstraction layer (AC: 1)
  - [x] Create `app/services/storage_service.py` as the ONLY interface to S3/Cloudinary
  - [x] Implement `upload_pdf(*, user_id, document_id, fileobj, content_type) -> str` returning a persisted `file_path` identifier
  - [x] Use `boto3` (installed) with `anyio.to_thread.run_sync(...)` (or equivalent) to avoid blocking the event loop
  - [x] Store objects under a user-scoped key prefix (e.g., `users/{user_id}/documents/{document_id}.pdf`) for isolation and easy cleanup later

- [x] Add document repository primitives (AC: 1)
  - [x] Create `app/repositories/document_repository.py` with async SQLAlchemy 2.0 functions:
    - [x] `create_document(session, *, user_id, title, file_path, file_size, page_count, status) -> Document`
  - [x] IMPORTANT: `Document.page_count` is non-nullable in the existing model/migration; set it to a safe placeholder (recommend `0`) on creation and update later in Story 3.2

- [x] Add integration tests (AC: 1–3)
  - [x] Create `tests/integration/test_documents_upload.py`:
    - [x] unauthenticated request returns `401` with `detail.code: "INVALID_TOKEN"`
    - [x] valid PDF upload returns `201` (preferred) with `{id,title,status,created_at}`
    - [x] non-PDF bytes returns `422` with `detail.code: "INVALID_FILE_TYPE"`
    - [x] oversized upload returns `413` with `detail.code: "FILE_TOO_LARGE"`
  - [x] Testing strategy for storage:
    - [x] Do not call real AWS in tests.
    - [x] Either (a) dependency-inject `StorageService` and override it in tests, or (b) monkeypatch `storage_service.upload_pdf` to return a fake `file_path`.
    - [x] Keep size-limit logic testable by centralizing the limit constant so tests can temporarily lower the limit without allocating >50MB in-memory blobs.

## Dev Notes

### What already exists (reuse; do not reinvent)

- Standard error payload helper: `app/routers/errors.py::build_error_detail()`.
- Global validation error normalization: `app/main.py` has a `RequestValidationError` handler that forces the `{detail: {code,message,field}}` format.
- Auth dependency for endpoints: `CurrentUser` in `app/dependencies/auth.py`.
- Database model already present: `app/models/document.py` with `DocumentStatus` enum and required fields.
  - **Important constraint:** `page_count` is required (`nullable=False`) in both the SQLAlchemy model and Alembic migration. Upload must set a value immediately (recommend `0`) and Story 3.2 will compute and update it.

### API contract guidance (be explicit and consistent)

- Endpoint must be versioned and grouped:
  - Router prefix: `/api/v1/documents`
  - Upload path: `POST /upload`
- Prefer `201 Created` for a new Document record.
- Response should be a single object (not list wrapper), matching project conventions:
  - `id` (UUID string)
  - `title` (derived from filename)
  - `status` (should be `processing`)
  - `created_at` (UTC ISO 8601)

### Validation expectations (must follow)

- File type validation must check magic bytes `%PDF-` from the uploaded stream.
  - Do not rely on `.pdf` extension, `UploadFile.content_type`, or client-provided metadata.
- File size limit: 50 MB.
  - Do not trust `Content-Length` alone.
  - Ensure logic is safe for streaming uploads and does not read the entire file into memory.

### Storage service requirements

- Project context rule: `storage_service.py` is the sole interface to S3/Cloudinary.
- This repo already has AWS settings in `app/config.py` and `boto3` in `backend/requirements.txt`.
  - Prefer implementing S3 first using:
    - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `S3_BUCKET_NAME`
  - Store `file_path` in DB as the S3 object key (recommended) rather than a presigned URL.

### Data isolation and security

- Always associate uploads with `current_user.id` at the service layer.
- Ensure the storage object key includes the user scope (prefix) and the Document record includes `user_id`.

### Project Structure Notes

- Backend router patterns to follow: see `app/routers/auth.py` (HTTP-only logic + service orchestration + typed domain errors).
- Repository pattern to follow: see `app/repositories/user_repository.py` (async SQLAlchemy 2.0 `select()`, commit/refresh on create).
- Expected new modules for this epic (per architecture mapping):
  - `app/routers/documents.py`
  - `app/services/document_service.py`
  - `app/services/storage_service.py`
  - `app/repositories/document_repository.py`
  - `app/schemas/documents.py`

### Testing Notes

- Tests use `fastapi.testclient.TestClient` with an overridden async DB session factory (see `tests/conftest.py`).
- For file upload tests, use `client.post(..., files={"file": ("sample.pdf", pdf_bytes, "application/pdf")})`.
- Avoid huge allocations for size tests by making the max size constant patchable in tests.

### Out of Scope (do not implement here)

- Document processing pipeline stages (`extracting`, `chunking`, `embedding`) and page counting from real PDF parsing — Story 3.2+.
- Document library list/delete endpoints — Epic 4.
- Signed URL generation / direct-to-S3 uploads from mobile — optional future optimization, not required by AC.

### References

- Planning: `_bmad-output/planning-artifacts/epics.md` → “Epic 3: Document Upload & AI Processing Pipeline” → “Story 3.1: PDF Upload API and Cloud Storage”
- Architecture: `_bmad-output/planning-artifacts/architecture.md` → “Authentication & Security” (file validation + size limiting), “API Naming Conventions” (documents endpoints), “Requirements to Structure Mapping” (documents router/service/storage)
- Project rules: `_bmad-output/project-context.md` → “External Service Boundaries” (storage_service sole interface), “Critical Implementation Rules” (async everywhere, response formats)

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex (GitHub Copilot)

### Debug Log References

- Red phase: `pytest tests/integration/test_documents_upload.py -q` failed with `ModuleNotFoundError` for `app.services.storage_service` before implementation.
- Green phase: implemented documents router/service/repository/schema/storage modules and router mounting.
- Validation: `pytest tests/integration/test_documents_upload.py -q`, `pytest -q`, and `ruff check app tests` all passed.

### Completion Notes List

- Implemented authenticated `POST /api/v1/documents/upload` returning `201` with `id`, `title`, `status`, and `created_at`.
- Added streaming-safe PDF validation using magic bytes (`%PDF-`) and upload-size enforcement with a centralized `MAX_UPLOAD_SIZE_BYTES` constant.
- Added S3 storage abstraction with user-scoped object keys: `users/{user_id}/documents/{document_id}.pdf`.
- Added document persistence via repository with `page_count=0` placeholder and `processing` status on creation.
- Added integration tests covering auth failure, valid upload success, invalid file type, and oversized upload rejection.
- Verified no regressions: full backend tests and lint checks are green.

### File List

- backend/app/main.py
- backend/app/routers/documents.py
- backend/app/schemas/documents.py
- backend/app/services/document_service.py
- backend/app/services/storage_service.py
- backend/app/repositories/document_repository.py
- backend/tests/integration/test_documents_upload.py

## Change Log

- 2026-03-17: Implemented Story 3.1 upload API, storage abstraction, document persistence, and integration tests. Story moved to `review`.
