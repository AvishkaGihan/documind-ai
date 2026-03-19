import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({required this.documentId, super.key});

  final String documentId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    return Scaffold(
      backgroundColor: tokens.colors.surfacePrimary,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: 'document-$documentId',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: tokens.colors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.colors.borderDefault),
                  ),
                  child: Text(
                    'Document $documentId',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: tokens.colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: Center(
                child: Text(
                  'Chat Screen Placeholder: $documentId',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: tokens.colors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
