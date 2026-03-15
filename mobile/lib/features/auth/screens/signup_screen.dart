import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    return Scaffold(
      backgroundColor: tokens.colors.surfacePrimary,
      body: Center(
        child: Text(
          'Signup Screen Placeholder',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: tokens.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
