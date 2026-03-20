import 'dart:async';
import 'dart:convert';

import 'package:documind_ai/app.dart';
import 'package:documind_ai/features/auth/data/token_storage.dart';
import 'package:documind_ai/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpFrames(WidgetTester tester, [int count = 6]) async {
    for (var i = 0; i < count; i += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('App builds with ProviderScope and router shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      DocuMindApp(
        initialLocation: '/auth/login',
        overrides: [
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ProviderScope), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Unauthenticated users are redirected to login form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      DocuMindApp(
        initialLocation: '/library',
        overrides: [
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('login-email-field')), findsOneWidget);
  });

  testWidgets('Bootstrap route shows loading then navigates to library', (
    WidgetTester tester,
  ) async {
    final tokenStorage = _FakeTokenStorage(
      session: StoredAuthSession(
        accessToken: _tokenWithExpiry(minutesFromNow: 30),
        refreshToken: 'refresh-token',
        userId: 'user-id',
        email: 'user@example.com',
      ),
    );

    await tester.pumpWidget(
      DocuMindApp(
        initialLocation: '/',
        overrides: [tokenStorageProvider.overrideWithValue(tokenStorage)],
      ),
    );

    expect(find.byKey(const Key('auth-bootstrap-loader')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Document Library'), findsOneWidget);
    expect(find.byKey(const Key('login-email-field')), findsNothing);
  });

  testWidgets('Login screen renders inline validation errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      DocuMindApp(
        initialLocation: '/auth/login',
        overrides: [
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(
      find.byKey(const Key('login-email-field')),
      'invalid',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'short',
    );
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(
      find.text('Password must be at least 12 characters'),
      findsOneWidget,
    );
  });

  testWidgets('Bottom tabs switch active destination', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      DocuMindApp(
        initialLocation: '/library',
        overrides: [
          authStateProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        ],
      ),
    );
    await pumpFrames(tester, 10);

    expect(find.text('Document Library'), findsOneWidget);

    await tester.tap(find.text('Settings').first);
    await pumpFrames(tester, 6);
    expect(find.text('Settings Screen Placeholder'), findsOneWidget);

    await tester.tap(find.text('Chat').first);
    await pumpFrames(tester, 6);
    expect(find.byKey(const Key('chat-input-bar')), findsOneWidget);
  });
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  FutureOr<AuthState> build() =>
      const AuthState.authenticated(email: 'user@example.com');
}

String _tokenWithExpiry({required int minutesFromNow}) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final exp =
      DateTime.now()
          .toUtc()
          .add(Duration(minutes: minutesFromNow))
          .millisecondsSinceEpoch ~/
      1000;
  final payload = base64Url.encode(utf8.encode('{"exp":$exp}'));
  return '$header.$payload.signature';
}

class _FakeTokenStorage implements TokenStorage {
  _FakeTokenStorage({this.session});

  StoredAuthSession? session;

  @override
  Future<void> clear() async {
    session = null;
  }

  @override
  Future<StoredAuthSession?> readSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return session;
  }

  @override
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    String? userId,
    String? email,
  }) async {
    session = StoredAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      email: email,
    );
  }
}
