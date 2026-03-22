# Sprint Change Proposal - Settings Screen & Auth Polish

**Date:** 2026-03-21
**Author:** Antigravity (AI Agent)
**Status:** Pending Review

---

## 1. Issue Summary

### Trigger
The user identified that while initially planned epics are complete, the **Settings Screen** remains a placeholder. Additionally, the **Authentication Screens** (Login/Signup) are described as "dull" and require visual polish and branding elements to align with a premium experience.

### Core Problem
-   **Settings Screen Gap**: The initial Epic breakdown (Epics 1-6) configured the Settings tab as a placeholder but did not include stories for implementing its functional contents (Logout, Password Reset UI, Account Deletion, Theme Toggle).
-   **Auth Aesthetics gap**: Basic functionality exists but lacks the "Hybrid Premium" visual identity (logos, rich gradients, branding) desired for a portfolio-grade app.
-   **Backend Gap**: Completing the Settings screen requires full support for NFR10 (Account Deletion), which is currently missing a backend endpoint (`DELETE /api/v1/user/me`).

---

## 2. Impact Analysis

### Epic Impact
-   **Epic 2 (Authentication)**: Requires a new story for visual polish and branding.
-   **Epic 4 (Library) or New Epic**: Implementing a fully functional Settings screen is distinct enough to warrant a **new Epic** or a significant expansion of Epic 2/4. Creating **Epic 7** is recommended for clean backlog organization.

### Artifact Conflicts
-   **`epics.md`**: Needs update to append Epic 7 and expand Epic 2.
-   **`backend/app/routers/auth.py`**: Needs a new endpoint for account deletion.
-   **`mobile/lib/features/settings`**: Needs full implementation of the view and providers.

---

## 3. Recommended Approach

### **Option 1: Create Epic 7 (Recommended)**
Create a dedicated Epic for Settings and Profile Management, and add a branding story to Epic 2. This maintains high organization and allows tracking these refinements as distinct deliverables.

**Effort Estimate:** Medium (1-2 days equivalent)
**Risk Level:** Low

### Rationale
This approach explicitly addresses the "missing" scope described by the user while ensuring backend consistency (adding the missing delete endpoint) to fulfill NFR10 completely.

---

## 4. Detailed Change Proposals

### 4.1. Modifications to `epics.md`

#### [ADD] to Epic 2: User Authentication & Account Management

```markdown
### Story 2.6: Auth Screens Visual Polish & Branding [NEW]

As a mobile user,
I want to see beautiful, branded login and signup screens with rich aesthetics,
So that my first impression of the app is premium and trustworthy.

**Acceptance Criteria:**
- **Given** I am on the Login or Signup screen
- **When** I view the background and form
- **Then** I see the DocuMind AI Logo/Branding element at the top
- **And** the background uses a subtle glassmorphic effect or gradient aligned with the "Hybrid Premium" theme
- **And** input fields use custom borders and focus rings matching the accent color
- **And** login buttons use the full-width Primary style with rich hover/press states
```

#### [NEW] Epic 7: User Settings & Profile Management

```markdown
## Epic 7: User Settings & Profile Management [NEW]

Users can manage their account, toggle application themes, and delete their data securely from a dedicated settings screen.

### Story 7.1: Settings Screen UI & Theme Toggle

As a user,
I want a dedicated Settings screen to view my account info and customize app appearance,
So that I can manage my preferences.

**Acceptance Criteria:**
- **Given** I am on the Settings tab
- **When** the screen loads
- **Then** I see my account email displayed at the top
- **And** I see options for: "Theme" (Dark/Light toggle), "Reset Password", "Delete Account", and "Logout"
- **And** toggling the Theme instantly updates the app appearance (rebuilding with light/dark theme)
- **And** the UI consumes design tokens and is fully polished

### Story 7.2: Password Reset UI Flow

As a user,
I want to trigger a password reset from the settings screen,
So that I can secure my account if needed.

**Acceptance Criteria:**
- **Given** I am on the Settings screen
- **When** I tap "Reset Password"
- **Then** I am shown a confirmation dialog stating an email will be sent
- **And** tapping "Confirm" calls the `/api/v1/user/reset-password` endpoint
- **And** a success SnackBar confirms the action

### Story 7.3: Account Deletion Backend Endpoint [NEW BACKEND]

As a user,
I want to delete my account and all my data from the system,
So that I have full control over my data privacy (NFR10).

**Acceptance Criteria:**
- **Given** I am an authenticated user
- **When** I send a DELETE request to `/api/v1/user/me`
- **Then** the user record is deleted
- **And** ALL associated documents, vectors in ChromaDB, and conversations are cascade-deleted
- **And** 204 No Content is returned

### Story 7.4: Delete Account UI & Flow

As a user,
I want to be able to delete my account from the mobile app,
So that I can remove my data completely.

**Acceptance Criteria:**
- **Given** I am on the Settings screen
- **When** I tap "Delete Account"
- **Then** a high-warning red Dialog appears asking for confirmation
- **And** after confirming, the backend is called to delete the account
- **And** upon success, I am logged out and returned to the Login screen with a confirmation message
```

---

## 5. Implementation Handoff

### **Scope Classification: Minor to Moderate**
-   **Backend**: 1 new endpoint in `auth.py` or a new `user_router.py`.
-   **Frontend**: 1 new feature screen (`settings_screen.dart`) and UI tweaks to `login_screen.dart` and `signup_screen.dart`.

### Handoff Recipients
-   **Development Team**: To implement backend end-point and frontend views.
-   **Backlog updates**: Update `sprint-status.yaml` to include Epic 7 as `backlog` with 0/4 complete.

---
*Proposals are subject to collaborative refinement.*
