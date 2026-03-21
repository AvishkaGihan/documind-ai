import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

void showPersistentErrorSnackBar(
  BuildContext context,
  DocuMindTokens tokens,
  String message, {
  VoidCallback? onRetry,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: tokens.colors.accentError,
        duration: const Duration(days: 1),
        action: onRetry == null
            ? null
            : SnackBarAction(
                label: 'Retry',
                textColor: tokens.colors.textOnAccent,
                onPressed: onRetry,
              ),
      ),
    );
}

void showWarningSnackBar(
  BuildContext context,
  DocuMindTokens tokens,
  String message,
) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: tokens.colors.accentWarning,
        duration: const Duration(seconds: 5),
      ),
    );
}
