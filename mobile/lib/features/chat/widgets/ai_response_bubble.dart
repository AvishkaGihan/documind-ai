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

    final isThinking = message.content.isEmpty;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        margin: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left accent bar + AI indicator ─────────────────────────
              Column(
                children: [
                  // Sparkle avatar
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          tokens.colors.accentPrimary,
                          tokens.colors.accentAiGlow,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: tokens.colors.accentPrimary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '✦',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Vertical accent line
                  Expanded(
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            tokens.colors.accentPrimary.withValues(alpha: 0.5),
                            tokens.colors.accentPrimary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: AppSpacing.md),

              // ── Content ─────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI label
                      Text(
                        'DocuMind AI',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tokens.colors.accentPrimary,
                          letterSpacing: 0.4,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xs),

                      // Main content
                      if (isThinking)
                        Text(
                          'Thinking…',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.colors.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        _buildRichContent(context, tokens),

                      // Citations
                      if (message.citations.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: message.citations.asMap().entries.map((entry) {
                            final index = entry.key;
                            final citation = entry.value;
                            final excerpt =
                                citationExcerpts[citation.pageNumber] ??
                                citation.textExcerpt;
                            return CitationChip(
                              key: Key('citation-chip-${citation.pageNumber}'),
                              pageNumber: citation.pageNumber,
                              excerpt: excerpt,
                              isExpanded:
                                  expandedPages.contains(citation.pageNumber),
                              onToggle: () =>
                                  onToggleCitation(citation.pageNumber),
                            );
                          }).toList(growable: false),
                        ),
                      ],

                      // Timestamp
                      if (message.isComplete) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 11,
                              color: tokens.colors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timestamp,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: tokens.colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRichContent(BuildContext context, DocuMindTokens tokens) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      color: tokens.colors.textPrimary,
      height: 1.6,
    );

    final paragraphs = message.content.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.asMap().entries.map((entry) {
        final i = entry.key;
        final para = entry.value.trim();
        if (para.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.sm),
          child: _buildParagraph(context, para, baseStyle, tokens),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildParagraph(
    BuildContext context,
    String text,
    TextStyle? baseStyle,
    DocuMindTokens tokens,
  ) {
    final numberedLineRegex = RegExp(r'^(\d+)\.\s+(.+)$', multiLine: true);
    final lines = text.split('\n');

    if (lines.every((l) => numberedLineRegex.hasMatch(l.trim()))) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          final match = numberedLineRegex.firstMatch(line.trim());
          if (match == null) {
            return Text(line, style: baseStyle);
          }
          final number = match.group(1)!;
          final content = match.group(2)!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number.',
                  style: baseStyle?.copyWith(
                    color: tokens.colors.accentPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(content, style: baseStyle)),
              ],
            ),
          );
        }).toList(growable: false),
      );
    }

    return Text(text, style: baseStyle);
  }
}
