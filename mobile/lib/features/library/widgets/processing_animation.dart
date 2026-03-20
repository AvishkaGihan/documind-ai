import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

class ProcessingAnimation extends StatefulWidget {
  const ProcessingAnimation({
    required this.status,
    this.pageCount,
    this.compact = false,
    super.key,
  });

  final String status;
  final int? pageCount;
  final bool compact;

  @override
  State<ProcessingAnimation> createState() => _ProcessingAnimationState();
}

class _ProcessingAnimationState extends State<ProcessingAnimation>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller?.dispose();
      _controller = null;
      return;
    }

    _controller ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final stage = _stagePresentation(widget.status, widget.pageCount ?? 0);

    final label = Row(
      children: [
        Icon(stage.icon, size: 16, color: tokens.colors.accentAiGlow),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            stage.label,
            key: Key('processing-status-${widget.status}'),
            maxLines: widget.compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.colors.accentAiGlow,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    final controller = _controller;
    if (controller == null) {
      return label;
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(controller.value);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            child!,
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: 0.2 + (t * 0.6),
                backgroundColor: tokens.colors.surfaceTertiary,
                valueColor: AlwaysStoppedAnimation<Color>(
                  tokens.colors.accentAiGlow.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        );
      },
      child: label,
    );
  }
}

class ProcessingStagePresentation {
  const ProcessingStagePresentation({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

ProcessingStagePresentation _stagePresentation(String status, int pageCount) {
  switch (status) {
    case 'extracting':
      return ProcessingStagePresentation(
        icon: Icons.auto_stories_outlined,
        label: pageCount > 0
            ? 'Extracting text from $pageCount pages'
            : 'Extracting text',
      );
    case 'chunking':
      return const ProcessingStagePresentation(
        icon: Icons.grid_view_outlined,
        label: 'Creating knowledge chunks',
      );
    case 'embedding':
      return const ProcessingStagePresentation(
        icon: Icons.psychology_alt_outlined,
        label: 'Building intelligence index',
      );
    case 'processing':
      return const ProcessingStagePresentation(
        icon: Icons.sync_outlined,
        label: 'Processing document',
      );
    case 'ready':
      return const ProcessingStagePresentation(
        icon: Icons.check_circle_outline,
        label: 'Document ready',
      );
    case 'error':
      return const ProcessingStagePresentation(
        icon: Icons.error_outline,
        label: 'Processing failed',
      );
    default:
      return const ProcessingStagePresentation(
        icon: Icons.hourglass_bottom_outlined,
        label: 'Processing document',
      );
  }
}
