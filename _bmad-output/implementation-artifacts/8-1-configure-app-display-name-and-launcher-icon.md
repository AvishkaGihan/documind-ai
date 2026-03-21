# Story 8.1: Configure App Display Name and Launcher Icon

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user,
I want to see the correct app name and a branded logo on my home screen,
so that the app looks professional and easy to identify.

## Acceptance Criteria

1. The Android `android:label` and iOS `CFBundleDisplayName` are set to "DocuMind AI".
2. A custom launcher icon is generated using `flutter_launcher_icons`.
3. The icon uses the deep indigo/cyan branding of the project.

## Tasks / Subtasks

- [x] Task 1: Update App Display Name
  - [x] Set `android:label="DocuMind AI"` in `flutter_app/android/app/src/main/AndroidManifest.xml`
  - [x] Set `CFBundleDisplayName` to "DocuMind AI" in `flutter_app/ios/Runner/Info.plist`
- [x] Task 2: Configure Launcher Icon Package
  - [x] Add `flutter_launcher_icons` dev_dependency to `flutter_app/pubspec.yaml`
  - [x] Configure `flutter_launcher_icons` in `pubspec.yaml` (or a separate yaml)
- [x] Task 3: Create and Generate Icon Asset
  - [x] Create a base high-resolution logo/icon incorporating DocuMind AI's deep indigo/cyan branding.
  - [x] Place the icon asset in `flutter_app/assets/images/` or `flutter_app/assets/icons/`.
  - [x] Run `dart run flutter_launcher_icons` in the `flutter_app/` directory to generate platform-specific native assets.
- [x] Task 4: Verify Assets 
  - [x] Verify that iOS and Android mipmap/icon folders have been updated.

## Dev Notes

- **Technical Context**: This requires modifying native Android/iOS configuration files directly.
- **Project Structure**: All changes must take place inside the `flutter_app/` directory, rather than the backend project.
- **Branding Guidelines**: Follow the UX design specifications. The app uses a "Hybrid Premium" dark mode design. Deep indigo blues and electric cyan accents should be utilized for the icon. See `_bmad-output/planning-artifacts/ux-design-specification.md` for complete color definitions if needed, or inspect the existing Flutter `ThemeData`.
- **Package Usage**: Carefully follow the `flutter_launcher_icons` documentation. Ensure you create a high-resolution source image (e.g., 1024x1024) before running the builder.

### Project Structure Notes

- Flutter App Root: `flutter_app/`
- Android Manifest: `flutter_app/android/app/src/main/AndroidManifest.xml`
- iOS Plist: `flutter_app/ios/Runner/Info.plist`

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story-8-1]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md]

## Dev Agent Record

### Agent Model Used

antigravity

### Debug Log References

N/A

### Completion Notes List

- Updated Android and iOS configs with display name "DocuMind AI"
- Created branding icon in assets/icons/app_icon.png and ran flutter_launcher_icons
- Fixed adaptive icon fallback on Android by adding `adaptive_icon_background: "#0D1117"` and `adaptive_icon_foreground` configuration.
- Tested changes successfully and verified UI folders have valid generated icons
- [AI-Review] Cleaned up unused Android `launcher_icon.png` generated assets and finalized file list.

### File List

- `mobile/android/app/src/main/AndroidManifest.xml`
- `mobile/ios/Runner/Info.plist`
- `mobile/pubspec.yaml`
- `mobile/flutter_launcher_icons.yaml`
- `mobile/assets/icons/app_icon.png`
- `mobile/pubspec.lock`
- `mobile/ios/Runner.xcodeproj/project.pbxproj`
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `mobile/android/app/src/main/res/` (generated native icons)
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/` (generated native icons)
