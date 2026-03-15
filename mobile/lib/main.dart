import 'package:flutter/material.dart';

import 'core/theme/app_spacing.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'core/theme/theme_extensions.dart';

void main() {
  runApp(const DocuMindApp());
}

class DocuMindApp extends StatelessWidget {
  const DocuMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocuMind AI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const _ThemePreviewScreen(),
    );
  }
}

class _ThemePreviewScreen extends StatelessWidget {
  const _ThemePreviewScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('DocuMind AI')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Design System Foundation',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Dark theme defaults are wired through tokenized colors and typography.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.colors.accentCitation,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Page 12',
                    style: AppTypography.codeStyle(tokens.colors).copyWith(
                      color: tokens.colors.textOnAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Primary Action'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
