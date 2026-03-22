# Story 8.2: Configure Native Splash Screen

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user,
I want to see a branded splash screen immediately when the app launches,
so that the cold start transition is seamless and branded.

## Acceptance Criteria

1. A custom native splash screen is configured using `flutter_native_splash`.
2. Background color matches `--surface-primary` (`#0D1117`).
3. The splash screen centers the DocuMind AI logo.

## Tasks / Subtasks

- [x] Task 1: Add `flutter_native_splash` configuration
  - [x] Add `flutter_native_splash` to `dev_dependencies` in `mobile/pubspec.yaml`
  - [x] Configure `flutter_native_splash` in `mobile/pubspec.yaml` or `mobile/flutter_native_splash.yaml` with color `#0D1117` and image `assets/icons/app_icon.png`.
- [x] Task 2: Generate Splash Screen Assets
  - [x] Run `dart run flutter_native_splash:create` inside the `mobile` directory.
- [x] Task 3: Verify Assets
  - [x] Ensure the native Android and iOS folders received the generated splash screen assets.

## Dev Notes

**ARCHITECTURE COMPLIANCE**
- **File Structure Requirements**: The flutter app is located in `mobile/`. All commands and configurations must be executed in this directory.

**UX DESIGN REQUIREMENTS**
- **Splash Screen Branding**: `#0D1117` solid background with the centered launcher icon (DocuMind AI logo) to create a seamless transition into the app's dark mode scaffold. 

**LIBRARY / FRAMEWORK REQUIREMENTS**
- Use the `flutter_native_splash` package. It should be added as a `dev_dependency`.
- Configuration typically goes into a `flutter_native_splash.yaml` file to keep `pubspec.yaml` clean.
- Ensure Android 12+ splash screen is also appropriately handled (e.g. `android_12: true` in config).

**PREVIOUS STORY INTELLIGENCE (Story 8.1)**
- We have already created a branding icon at `assets/icons/app_icon.png` in the `mobile/` directory, which can be reused for the splash screen image.
- We used `.yaml` configs before. You can copy the pattern.
- The project's color palette relies heavily on the "Hybrid Premium" theme with extremely dark surfaces (like `#0D1117`).
- Keep in mind that `flutter_app/` in some old docs meant `mobile/`. The actual folder is `mobile/`.

### Project Structure Notes

- Flutter App Root: `mobile/`

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic-8:-App-Branding-&-Release-Preparation]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- Added `flutter_native_splash` to `mobile/pubspec.yaml` `dev_dependencies`.
- Configured native splash in `mobile/flutter_native_splash.yaml` using color `#0D1117` and the `app_icon.png` centered image.
- Successfully generated splash screen assets across Android and iOS using `dart run flutter_native_splash:create`.
- Verified assets in native Android and iOS folders.
- Ran test suite to verify no regressions were introduced.

### File List

- `mobile/pubspec.yaml`
- `mobile/flutter_native_splash.yaml`
- `mobile/android/app/src/main/res/drawable/launch_background.xml` (and related drawable versions)
- `mobile/android/app/src/main/res/values/styles.xml` (and related value types)
- `mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/*`
- `mobile/ios/Runner/Base.lproj/LaunchScreen.storyboard`
- `mobile/ios/Runner/Info.plist`
