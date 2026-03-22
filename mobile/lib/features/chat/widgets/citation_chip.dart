import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/shared/widgets/accessibility_focus_ring.dart';
import 'package:flutter/material.dart';

class CitationChip extends StatelessWidget {
  const CitationChip({
    required this.pageNumber,
    required this.excerpt,
    required this.isExpanded,
    required this.onToggle,
    super.key,
  });

  final int pageNumber;
  final String excerpt;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          toggled: isExpanded,
          label:
              'Page reference, page $pageNumber. Tap to view source. ${isExpanded ? 'Expanded' : 'Collapsed'}.',
          child: AccessibilityFocusRing(
            borderRadius: 24,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: ActionChip(
                key: Key('citation-chip-$pageNumber'),
                onPressed: onToggle,
                avatar: const ExcludeSemantics(child: Text('📄')),
                label: Text('Page $pageNumber'),
                side: BorderSide(color: tokens.colors.accentCitation),
                backgroundColor: tokens.colors.accentCitation.withValues(
                  alpha: 0.15,
                ),
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: tokens.colors.accentCitation,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: tokens.colors.surfaceTertiary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.colors.borderDefault),
            ),
            child: Text(
              excerpt,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.colors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
