import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/shared/widgets/accessibility_focus_ring.dart';
import 'package:flutter/material.dart';

class CitationChip extends StatefulWidget {
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
  State<CitationChip> createState() => _CitationChipState();
}

class _CitationChipState extends State<CitationChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expandController;
  late final Animation<double> _expandAnim;
  late final Animation<double> _chevronAnim;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.isExpanded ? 1.0 : 0.0,
    );
    _expandAnim = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _chevronAnim = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(covariant CitationChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Chip ────────────────────────────────────────────────────
          Semantics(
            button: true,
            toggled: widget.isExpanded,
            label:
                'Source citation, page ${widget.pageNumber}. ${widget.isExpanded ? 'Tap to collapse.' : 'Tap to view excerpt.'}',
            child: AccessibilityFocusRing(
              borderRadius: 20,
              child: GestureDetector(
                onTap: widget.onToggle,
                child: AnimatedBuilder(
                  animation: _expandController,
                  builder: (context, _) {
                    return Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.colors.surfaceTertiary.withValues(
                          alpha: 0.6,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: tokens.colors.accentCitation.withValues(
                            alpha: 0.35 + _expandAnim.value * 0.3,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.colors.accentCitation.withValues(
                              alpha: 0.05 + _expandAnim.value * 0.1,
                            ),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Gradient left indicator dot
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  tokens.colors.accentPrimary,
                                  tokens.colors.accentCitation,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.description_outlined,
                            size: 14,
                            color: tokens.colors.accentCitation,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Page ${widget.pageNumber}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.colors.accentCitation,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Animated chevron
                          RotationTransition(
                            turns: Tween<double>(begin: 0, end: 0.5)
                                .animate(_chevronAnim),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: tokens.colors.accentCitation.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ── Excerpt panel ─────────────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            child: FadeTransition(
              opacity: _expandAnim,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: tokens.colors.surfaceTertiary.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: tokens.colors.accentCitation.withValues(alpha: 0.2),
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      // Left accent bar
                      Container(
                        width: 3,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              tokens.colors.accentPrimary,
                              tokens.colors.accentCitation,
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(
                            widget.excerpt,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: tokens.colors.textSecondary,
                                  height: 1.6,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
