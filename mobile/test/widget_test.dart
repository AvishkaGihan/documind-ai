import 'package:documind_ai/core/theme/app_colors.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App boots with dark mode and theme tokens available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DocuMindApp());

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);

    final context = tester.element(find.byType(Scaffold));
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>();

    expect(tokens, isNotNull);
    expect(tokens!.colors.surfacePrimary, AppColors.dark.surfacePrimary);
    expect(find.text('DocuMind AI'), findsOneWidget);
  });
}
