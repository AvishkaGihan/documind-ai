import 'dart:async';

import 'package:documind_ai/core/theme/app_theme.dart';
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
}

Widget _buildApp() {
  return ProviderScope(
    overrides: [
      initialLocationProvider.overrideWithValue('/settings'),
      authStateProvider.overrideWith(_AuthenticatedAuthNotifier.new),
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
