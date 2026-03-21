import 'dart:async';

import 'package:dio/dio.dart';
import 'package:documind_ai/core/theme/app_theme.dart';
import 'package:documind_ai/features/auth/data/auth_api.dart';
import 'package:documind_ai/features/auth/providers/auth_provider.dart';
import 'package:documind_ai/features/settings/providers/theme_mode_provider.dart';
import 'package:documind_ai/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpFrames(WidgetTester tester, [int count = 6]) async {
    for (var i = 0; i < count; i += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('shows authenticated email and settings options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await pumpFrames(tester, 8);

    expect(find.text('Settings'), findsWidgets);
    expect(find.byKey(const Key('settings-email-header')), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });

  testWidgets('theme controls expose explicit dark and light choices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await pumpFrames(tester, 8);

    expect(find.byKey(const Key('settings-theme-dark-button')), findsOneWidget);
    expect(
      find.byKey(const Key('settings-theme-light-button')),
      findsOneWidget,
    );
  });

  testWidgets('selecting theme updates MaterialApp.router themeMode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await pumpFrames(tester, 8);

    MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    await tester.tap(find.byKey(const Key('settings-theme-light-button')));
    await tester.pump(const Duration(milliseconds: 120));

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);

    await tester.tap(find.byKey(const Key('settings-theme-dark-button')));
    await tester.pump(const Duration(milliseconds: 120));

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('tapping Reset Password opens confirmation dialog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await pumpFrames(tester, 8);

    await tester.tap(find.byKey(const Key('settings-action-reset-password')));
    await pumpFrames(tester, 4);

    expect(find.text('Reset Password'), findsWidgets);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('confirming reset calls AuthApi.resetPassword with user email', (
    WidgetTester tester,
  ) async {
    String? capturedEmail;
    final fakeAuthApi = _FakeAuthApi(
      onReset: (email) {
        capturedEmail = email;
      },
    );

    await tester.pumpWidget(
      _buildApp(overrides: [authApiProvider.overrideWithValue(fakeAuthApi)]),
    );
    await pumpFrames(tester, 8);

    await tester.tap(find.byKey(const Key('settings-action-reset-password')));
    await pumpFrames(tester, 3);

    await tester.tap(find.text('Confirm'));
    await pumpFrames(tester, 6);

    expect(capturedEmail, 'user@example.com');
  });

  testWidgets('successful reset shows a success SnackBar', (
    WidgetTester tester,
  ) async {
    final fakeAuthApi = _FakeAuthApi();

    await tester.pumpWidget(
      _buildApp(overrides: [authApiProvider.overrideWithValue(fakeAuthApi)]),
    );
    await pumpFrames(tester, 8);

    await tester.tap(find.byKey(const Key('settings-action-reset-password')));
    await pumpFrames(tester, 3);

    await tester.tap(find.text('Confirm'));
    await pumpFrames(tester, 6);

    expect(
      find.text('If an account exists, a password reset email has been sent.'),
      findsOneWidget,
    );
  });

  testWidgets('failed reset shows persistent error SnackBar', (
    WidgetTester tester,
  ) async {
    final fakeAuthApi = _FakeAuthApi(
      throwError: const AuthApiError(
        code: 'NETWORK_ERROR',
        message: 'Unable to reach the server. Please try again.',
      ),
    );

    await tester.pumpWidget(
      _buildApp(overrides: [authApiProvider.overrideWithValue(fakeAuthApi)]),
    );
    await pumpFrames(tester, 8);

    await tester.tap(find.byKey(const Key('settings-action-reset-password')));
    await pumpFrames(tester, 3);

    await tester.tap(find.text('Confirm'));
    await pumpFrames(tester, 6);

    expect(
      find.text('Unable to reach the server. Please try again.'),
      findsOneWidget,
    );
  });
}

Widget _buildApp({List overrides = const []}) {
  return ProviderScope(
    overrides: [
      initialLocationProvider.overrideWithValue('/settings'),
      authStateProvider.overrideWith(_AuthenticatedAuthNotifier.new),
      ...overrides,
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final router = ref.watch(appRouterProvider);
        final mode = ref.watch(themeModeProvider);
        return MaterialApp.router(
          theme: AppTheme.lightTheme.copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          darkTheme: AppTheme.darkTheme.copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          themeMode: mode,
          routerConfig: router,
        );
      },
    ),
  );
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  FutureOr<AuthState> build() =>
      const AuthState.authenticated(email: 'user@example.com');
}

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi({this.onReset, this.throwError}) : super(Dio());

  final void Function(String email)? onReset;
  final AuthApiError? throwError;

  @override
  Future<void> resetPassword({required String email}) async {
    onReset?.call(email);
    if (throwError case final error?) {
      throw error;
    }
  }
}
