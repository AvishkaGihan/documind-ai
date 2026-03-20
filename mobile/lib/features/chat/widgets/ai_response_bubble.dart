import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:documind_ai/features/chat/widgets/citation_chip.dart';
import 'package:flutter/material.dart';

class AiResponseBubble extends StatelessWidget {
  const AiResponseBubble({
    required this.message,
    required this.expandedPages,
    required this.citationExcerpts,
    required this.onToggleCitation,
    super.key,
  });

  final ChatMessage message;
  final Set<int> expandedPages;
  final Map<int, String> citationExcerpts;
  final ValueChanged<int> onToggleCitation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final timestamp = TimeOfDay.fromDateTime(
      message.createdAt.toLocal(),
    ).format(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: tokens.colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.colors.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content.isEmpty ? 'Thinking...' : message.content,
              key: const Key('ai-response-text'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.colors.textPrimary,
              ),
            ),
            if (message.citations.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: message.citations
                    .map((citation) {
                      final excerpt =
                          citationExcerpts[citation.pageNumber] ??
                          citation.textExcerpt;
                      return CitationChip(
                        pageNumber: citation.pageNumber,
                        excerpt: excerpt,
                        isExpanded: expandedPages.contains(citation.pageNumber),
                        onToggle: () => onToggleCitation(citation.pageNumber),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
            if (message.isComplete) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                timestamp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.colors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
