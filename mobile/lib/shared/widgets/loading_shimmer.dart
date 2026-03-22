import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

class LoadingShimmer extends StatefulWidget {
  const LoadingShimmer({required this.child, super.key});

  final Widget child;

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer>
    with TickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncControllerForMotionPreference();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _syncControllerForMotionPreference() {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      _controller?.dispose();
      _controller = null;
      return;
    }

    _controller ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;
    final controller = _controller;

    if (controller == null) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        final t = controller.value;
        final begin = Alignment(-1.6 + (t * 3.2), -0.4);
        final end = Alignment(-0.6 + (t * 3.2), 0.4);

        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: begin,
              end: end,
              colors: [
                tokens.colors.surfaceTertiary.withValues(alpha: 0.55),
                tokens.colors.surfaceSecondary.withValues(alpha: 0.3),
                tokens.colors.surfaceTertiary.withValues(alpha: 0.55),
              ],
              stops: const [0.2, 0.5, 0.8],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class LoadingShimmerBox extends StatelessWidget {
  const LoadingShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    super.key,
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return LoadingShimmer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.surfaceTertiary,
          borderRadius: borderRadius,
          border: Border.all(color: tokens.colors.borderDefault),
        ),
        child: SizedBox(width: width, height: height),
      ),
    );
  }
}

class LibraryDocumentSkeletonCard extends StatelessWidget {
  const LibraryDocumentSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          LoadingShimmerBox(
            width: 28,
            height: 28,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingShimmerBox(width: 180, height: 16),
                SizedBox(height: AppSpacing.sm),
                LoadingShimmerBox(width: 220, height: 12),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          LoadingShimmerBox(
            width: 12,
            height: 12,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ],
      ),
    );
  }
}
