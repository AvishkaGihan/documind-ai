import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

class AuthBootstrapScreen extends StatelessWidget {
  const AuthBootstrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    return Scaffold(
      backgroundColor: tokens.colors.surfacePrimary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                key: Key('auth-bootstrap-loader'),
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Loading your session...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
