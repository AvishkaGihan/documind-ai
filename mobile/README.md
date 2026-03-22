# 📱 DocuMind AI - Mobile App

The mobile client for DocuMind AI, built with **Flutter**, offering a smooth Material 3 experience for chatting with your documents.

---

## ✨ Features

- 🎨 **Material 3 Design**: Fully custom theme extensions for a modern, unified aesthetic.
- 🔄 **Async State Management**: Powered by **Riverpod 3** `AsyncNotifier` for reactive streams.
- 📦 **Immutable State**: Leverages `@freezed` for safe, declarative data passing.
- 🔐 **Secure Storage**: JWT tokens stored securely via `flutter_secure_storage` (iOS Keychain/Android Keystore).

---

## 🛠️ Tech Stack

- **Framework**: Flutter 3.41+ (Dart 3.x)
- **State Management**: [Riverpod](https://riverpod.dev)
- **Routing**: [go_router](https://pub.dev/packages/go_router)
- **HTTP Client**: [Dio](https://pub.dev/packages/dio)
- **Local Storage**: `flutter_secure_storage`

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and configured.
- Android Studio / VS Code with Flutter extension.

### Setup & Run

1.  **Navigate to directory**:
    ```bash
    cd mobile
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Configure Environment**:
    Create or verify `assets/config/.env` (if applicable) or ensure the API endpoint points to your backend. By default, it connects to `http://localhost:8000` in development.

4.  **Run the application**:
    ```bash
    flutter run
    ```

---

## 📂 Project Structure

```text
lib/
├── core/                  # Navigation, Themes, State constants
├── features/              # Feature-based architecture
│   ├── auth/              # Login, Signup screen & providers
│   ├── chat/              # AI dialogs & streams
│   └── library/           # Document lists & upload managers
└── shared/                # Global widgets (Buttons, Loaders)
```

## 🧪 Testing

Run standard tests:
```bash
flutter test
```
The CI/CD pipeline triggers on push to verify formatting (`flutter analyze`) and tests.
