# Sprint Change Proposal: App Branding & Initialization Polish

**Date:** 2026-03-22
**Triggering Issue:** All epics have been built, but the final mobile application still uses the default Flutter launcher icon, default splash screen, and an improper app name. These are required for a polished, professional release.
**Scope Classification:** Minor (Direct implementation by dev team)

---

## 1. Issue Summary
After completing the defined epics, a review of the built application on mobile devices revealed that the app retains the default Flutter branding. Specifically:
- The app name displayed on the device home screen is incorrect/unpolished (e.g., `documind_ai` instead of `DocuMind AI`).
- The launcher icon is the default Flutter logo.
- The native splash screen shown during the app's cold start is the default white screen with the Flutter logo.

These missing elements conflict with the "Hybrid Premium" design direction and the project's goal of portfolio-grade polish.

---

## 2. Impact Analysis

- **Epic Impact:** All current epics (1-7) are completed. We need to introduce a new Epic 8 specifically for "App Branding & Release Preparation" to house these final deployment polish tasks.
- **Story Impact:** New stories must be created to implement `flutter_launcher_icons` and `flutter_native_splash`.
- **Artifact Conflicts:** 
  - **PRD:** Needs a minor update to explicitly list app branding as a core requirement for MVP polish.
  - **UX Design Specification:** Needs an addendum defining the visual assets for the launcher icon and splash screen to match the "Midnight Intelligence" brand identity.
- **Technical Impact:** Low. Requires adding two standard Flutter dev dependencies (`flutter_launcher_icons` and `flutter_native_splash`), configuring their YAML files, and generating the native assets.

---

## 3. Recommended Approach

**Path Forward: Direct Adjustment (New Epic)**
We will create a new Epic 8 to encapsulate these branding requirements. Since this represents the final layer of polish before calling the application "done", it fits perfectly as a closing epic. 

- **Effort Estimate:** Low
- **Risk Level:** Low
- **Rationale:** This approach doesn't require rolling back any existing work and naturally extends the project's progression toward a production-ready state.

---

## 4. Detailed Change Proposals

### A. Stories and Epics Update (`epics.md`)
We will append Epic 8 to the Epic List.

```text
NEW EPIC:
### Epic 8: App Branding & Release Preparation
The app delivers a cohesive, premium brand experience outside of the UI by configuring the native launcher icon, app display name, and native splash screen to match the Design System.
**FRs covered:** Mobile Experience Polish

NEW STORIES:
### Story 8.1: Configure App Display Name and Launcher Icon
As a user,
I want to see the correct app name and a branded logo on my home screen,
So that the app looks professional and easy to identify.
*Acceptance Criteria:*
- The Android `android:label` and iOS `CFBundleDisplayName` are set to "DocuMind AI".
- A custom launcher icon is generated using `flutter_launcher_icons`.
- The icon uses the deep indigo/cyan branding of the project.

### Story 8.2: Configure Native Splash Screen
As a user,
I want to see a branded splash screen immediately when the app launches,
So that the cold start transition is seamless and branded.
*Acceptance Criteria:*
- A custom native splash screen is configured using `flutter_native_splash`.
- Background color matches `--surface-primary` (#0D1117).
- The splash screen centers the DocuMind AI logo.
```

### B. PRD Update (`prd.md`)
Modify the MVP Feature Set (Phase 1) Must-Have Capabilities to include:

```text
OLD:
| Clean, polished mobile UI | Portfolio presentation quality |

NEW:
| Clean, polished mobile UI | Portfolio presentation quality |
| Native App Branding (Icon & Splash) | Professional installation and cold-start experience |
```

### C. UX Design Specification Update (`ux-design-specification.md`)
Add definitions for the new visual elements under `Visual Design Foundation`.

```text
NEW:
### App Branding Assets
- **Launcher Icon:** A minimalist icon featuring the primary electric blue accent (#58A6FF) against a deep dark background (#0D1117). 
- **Splash Screen:** #0D1117 solid background with the centered launcher icon to create a seamless transition into the app's dark mode scaffold.
```

---

## 5. Implementation Handoff

- **Change Scope:** Minor
- **Target Agent:** bmad-dev (Development Team)
- **Implementation Tasks:**
  1. Approve this proposal.
  2. The PM agent will update `epics.md`, `prd.md`, `ux-design-specification.md`, and `sprint-status.yaml` with Epic 8.
  3. The Dev agent will generate the visual assets and implement `flutter_launcher_icons` and `flutter_native_splash` in the codebase.
