from pathlib import Path


def _read_file(path: Path) -> str:
    with path.open(encoding="utf-8") as file:
        return file.read()


def test_backend_ci_workflow_contains_required_steps() -> None:
    repo_root = Path(__file__).resolve().parents[3]
    workflow_path = repo_root / ".github" / "workflows" / "backend-ci.yml"

    assert workflow_path.exists()

    workflow = _read_file(workflow_path)

    assert "on:" in workflow
    assert "push:" in workflow
    assert "pull_request:" in workflow
    assert "actions/setup-python@v5" in workflow
    assert "python-version: \"3.12\"" in workflow
    assert "cache: pip" in workflow
    assert "cache-dependency-path: backend/requirements.txt" in workflow
    assert "working-directory: backend" in workflow
    assert "pip install -r requirements.txt" in workflow
    assert "ruff check ." in workflow
    assert "pytest" in workflow


def test_mobile_ci_workflow_contains_required_steps() -> None:
    repo_root = Path(__file__).resolve().parents[3]
    workflow_path = repo_root / ".github" / "workflows" / "mobile-ci.yml"

    assert workflow_path.exists()

    workflow = _read_file(workflow_path)

    assert "on:" in workflow
    assert "push:" in workflow
    assert "pull_request:" in workflow
    assert "subosito/flutter-action@v2" in workflow
    assert "channel: stable" in workflow
    assert "cache: true" in workflow
    assert "working-directory: mobile" in workflow
    assert "flutter pub get" in workflow
    assert "flutter analyze" in workflow
    assert "flutter test" in workflow
