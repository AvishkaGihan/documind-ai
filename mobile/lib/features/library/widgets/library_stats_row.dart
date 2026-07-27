import 'dart:ui';

import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/library/widgets/staggered_list_animation.dart';
import 'package:flutter/material.dart';

/// A horizontal row of glassmorphic "stat pill" cards that shows
/// total documents, ready count, and processing count at a glance.
class LibraryStatsRow extends StatelessWidget {
  const LibraryStatsRow({
    required this.totalCount,
    required this.readyCount,
    required this.processingCount,
    super.key,
  });

  final int totalCount;
  final int readyCount;
  final int processingCount;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return Row(
      children: [
        Expanded(
          child: StaggeredListItem(
            index: 0,
            child: _StatPill(
              icon: Icons.library_books_rounded,
              label: 'Total',
              count: totalCount,
              accentColor: tokens.colors.accentPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StaggeredListItem(
            index: 1,
            child: _StatPill(
              icon: Icons.check_circle_rounded,
              label: 'Ready',
              count: readyCount,
              accentColor: tokens.colors.accentSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StaggeredListItem(
            index: 2,
            child: _ProcessingStatPill(
              count: processingCount,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Standard stat pill ─────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.count,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: tokens.colors.surfaceSecondary.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tokens.colors.borderDefault.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: tokens.colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: tokens.colors.textTertiary,
                        fontSize: 10,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Processing stat pill with pulsing glow ─────────────────────────────────

class _ProcessingStatPill extends StatefulWidget {
  const _ProcessingStatPill({required this.count});

  final int count;

  @override
  State<_ProcessingStatPill> createState() => _ProcessingStatPillState();
}

class _ProcessingStatPillState extends State<_ProcessingStatPill>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion || widget.count == 0) {
      _pulseController?.dispose();
      _pulseController = null;
      return;
    }

    _pulseController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ProcessingStatPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count == 0 && _pulseController != null) {
      _pulseController?.dispose();
      _pulseController = null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;
    final controller = _pulseController;

    final pill = _StatPill(
      icon: Icons.sync_rounded,
      label: 'Processing',
      count: widget.count,
      accentColor: tokens.colors.accentAiGlow,
    );

    if (controller == null || widget.count == 0) {
      return pill;
    }

    return AnimatedBuilder(
      animation: controller,
      child: pill,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: tokens.colors.accentAiGlow.withValues(
                  alpha: 0.15 + (t * 0.15),
                ),
                blurRadius: 8 + (t * 8),
                spreadRadius: -2 + (t * 2),
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
