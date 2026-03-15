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
      body: Center(
        child: Text(
          'Chat Screen Placeholder: $documentId',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: tokens.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
