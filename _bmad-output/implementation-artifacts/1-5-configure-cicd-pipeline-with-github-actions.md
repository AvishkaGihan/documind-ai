# Story 1.5: Configure CI/CD Pipeline with GitHub Actions

Status: in-progress

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want to set up GitHub Actions workflows for both backend and frontend,
so that code quality is automatically validated on every push and pull request.

## Acceptance Criteria

1. **Given** both backend and frontend projects are initialized
   **When** I create CI/CD configuration files
   **Then** `.github/workflows/backend-ci.yml` runs on push/PR: installs Python dependencies, runs `ruff` linting, runs `pytest`

2. **Given** both backend and frontend projects are initialized
   **When** I create CI/CD configuration files
   **Then** `.github/workflows/mobile-ci.yml` runs on push/PR: installs Flutter, runs `flutter analyze`, runs `flutter test`

3. **Given** CI should be fast enough for frequent iteration
   **When** CI runs on push/PR
   **Then** both workflows use appropriate caching (pip cache, pub cache)

4. **Given** CI is wired correctly
   **When** CI runs on the initial codebase
   **Then** both workflows pass successfully

## Tasks / Subtasks

- [x] Add backend CI workflow (AC: 1, 3)
  - [x] Create `.github/workflows/backend-ci.yml`
  - [x] Use `actions/setup-python@v5` with `python-version: "3.12"` (aligns with backend `ruff` target-version `py312`)
  - [x] Enable pip caching via `cache: pip` and `cache-dependency-path: backend/requirements.txt`
  - [x] In job steps, run from `backend/`:
    - [x] `pip install -r requirements.txt`
    - [x] `ruff check .`
    - [x] `pytest`

- [x] Add mobile CI workflow (AC: 2, 3)
  - [x] Create `.github/workflows/mobile-ci.yml`
  - [x] Install Flutter using `subosito/flutter-action@v2` on the `stable` channel
  - [x] Enable caching (Flutter SDK + pub cache) via the action’s `cache: true`
  - [x] In job steps, run from `mobile/`:
    - [x] `flutter pub get`
    - [x] `flutter analyze`
    - [x] `flutter test`

- [ ] Verification gates (AC: 4)
  - [ ] Open a PR and confirm both workflows run
  - [ ] Ensure both workflows pass on the current mainline codebase

## Dev Notes

### Developer context (avoid common CI mistakes)

- There are currently no workflows under `.github/workflows/` — this story introduces the first CI configuration.
- Backend uses `ruff` and `pytest` (both are already in `backend/requirements.txt`). Ruff configuration lives in `backend/pyproject.toml` and targets Python 3.12.
- Mobile uses `flutter_lints` via `mobile/analysis_options.yaml` and tests via `flutter_test`.

### Project Structure Notes

- CI workflow files MUST live in `.github/workflows/` (architecture rule).
- Backend commands should run with `working-directory: backend` so `pytest` discovers `tests/` and `ruff` reads `backend/pyproject.toml`.
- Mobile commands should run with `working-directory: mobile` so Flutter uses the correct `pubspec.yaml`.

### Git intelligence (recent patterns to follow)

- Recent work has been done via story branches merged into `develop` (e.g., Story 1.4 merged recently). CI should run against PRs targeting `develop` as well as direct pushes.
- Latest commits (titles):
  - `Merge pull request #4 from AvishkaGihan/story/1-4-setup-database-alembic`
  - `feat(backend): set up database models and alembic migrations (Story 1.4)`
  - `feat(status): update story status to 'done' for routing and state management`
  - `Merge pull request #3 from AvishkaGihan/story/1-3-configure-routing`
  - `feat(mobile): configure routing, state management, and app shell (Story 1.3)`

### Previous Story Intelligence (from Story 1.4)

- `ruff` is enforced in the repo and may require fixing style issues in generated files (e.g., Alembic revisions). Prefer `ruff check . --fix` when needed.
- Python dependency installs can occasionally fail due to network flakiness; when diagnosing CI-only failures, retrying/pinning problematic wheels is often the fastest route.

### References

- Story requirements + acceptance criteria: `_bmad-output/planning-artifacts/epics.md` → Epic 1 → Story 1.5
- CI/CD location and expectations: `_bmad-output/planning-artifacts/architecture.md` → Infrastructure & Deployment → CI/CD Pipeline Approach; and File Organization Patterns → Configuration Files
- Backend toolchain (Python 3.12, ruff, pytest): `_bmad-output/project-context.md` → Technology Stack & Versions; Testing Rules; Development Workflow Rules
- Existing backend configuration: `backend/pyproject.toml`, `backend/requirements.txt`
- Existing mobile configuration: `mobile/pubspec.yaml`, `mobile/analysis_options.yaml`

## Dev Agent Record

### Agent Model Used

GPT-5.3-Codex

### Debug Log References

- Story selected from `_bmad-output/implementation-artifacts/sprint-status.yaml`: `1-5-configure-cicd-pipeline-with-github-actions` (first `ready-for-dev` story in top-to-bottom order).
- Red phase validation: `cd backend && .venv/bin/python -m pytest tests/unit/test_ci_workflows.py -q` failed with missing workflow files.
- Green and regression validation:
  - `cd backend && .venv/bin/python -m pytest tests/unit/test_ci_workflows.py -q` -> passed
  - `cd backend && .venv/bin/python -m ruff check .` -> passed
  - `cd backend && .venv/bin/python -m pytest -q` -> passed (10 tests)
  - `cd mobile && flutter pub get && flutter analyze && flutter test` -> passed

### Completion Notes List

- Added `.github/workflows/backend-ci.yml` with Python 3.12 setup, pip cache, Ruff lint, and pytest steps in `backend/`.
- Added `.github/workflows/mobile-ci.yml` with stable Flutter setup, action cache enabled, and analyze/test steps in `mobile/`.
- Added backend unit tests in `backend/tests/unit/test_ci_workflows.py` to assert required workflow files and key CI commands.
- Verification-gate PR checks remain pending because opening and running an actual GitHub PR workflow is outside this local environment.

### File List

- _bmad-output/implementation-artifacts/1-5-configure-cicd-pipeline-with-github-actions.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- .github/workflows/backend-ci.yml
- .github/workflows/mobile-ci.yml
- backend/tests/unit/test_ci_workflows.py

## Change Log

- 2026-03-16: Implemented backend/mobile GitHub Actions workflows with caching and added CI workflow validation tests.
