import 'dart:async';

import 'package:documind_ai/app.dart';
import 'package:documind_ai/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App builds with ProviderScope and router shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DocuMindApp(initialLocation: '/auth/login'));
    await tester.pumpAndSettle();

    expect(find.byType(ProviderScope), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Unauthenticated users are redirected to login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DocuMindApp(initialLocation: '/library'));
    await tester.pumpAndSettle();

    expect(find.text('Login Screen Placeholder'), findsOneWidget);
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
    await tester.pumpAndSettle();

    expect(find.text('Library Screen Placeholder'), findsOneWidget);

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    expect(find.text('Settings Screen Placeholder'), findsOneWidget);

    await tester.tap(find.text('Chat').first);
    await tester.pumpAndSettle();
    expect(find.text('Chat Screen Placeholder: active'), findsOneWidget);
  });
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  FutureOr<AuthState> build() => const AuthState(isAuthenticated: true);
}
