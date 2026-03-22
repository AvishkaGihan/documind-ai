# Contributing to DocuMind AI

Thank you for considering contributing to DocuMind AI! To maintain a high-quality codebase and smooth workflows, please follow these guidelines.

---

## 🌿 Branching Strategy

We use structured branches for features, fixes, and docs.

- **Feature Work**: `feature/feature-name` or `feature/issue-number-description`
- **Bug Fixes**: `bugfix/fix-name`
- **Documentation**: `docs/doc-update`

---

## 🛠️ Code Style & Quality

All code submitted must pass local linting before opening a Pull Request.

### 🐍 Backend (Python)
We use `ruff` for both linting and formatting.
- **Run Check**: `ruff check .`
- **Auto-Format**: `ruff format .`

### 📱 Mobile (Flutter)
We enforce structure through Riverpod naming rules and standard flutter_lints.
- **Run Analyzer**: `flutter analyze`
- **Run Tests**: `flutter test`

---

## ✉️ Pull Request Process

1.  **Fork & Branch**: Create your branch from `main` or `develop` (whichever is standard for the sprint).
2.  **Implement**: Add your logic, preserving backwards compatibility and maintaining **strict single service boundaries** as detailed in `docs/project-context.md`.
3.  **Test**: Ensure all unit and integration tests are passing locally.
4.  **Submit**:
    -   Keep titles descriptive (`feat: add citation clicks`).
    -   Fill out the PR Template checklist completely.
    -   Link to any related issues.

---

## 🔒 Security Expectations
DocuMind AI enforces physical data separation. **Never bypass service layer checks** for `user_id` validation. Any attempt to query raw tables containing multiple owners without proper service abstractions will be rejected.
