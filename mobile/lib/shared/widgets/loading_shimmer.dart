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

/// Updated skeleton card matching the redesigned [DocumentCard] layout:
/// accent bar + icon + title/metadata + status chip.
class LibraryDocumentSkeletonCard extends StatelessWidget {
  const LibraryDocumentSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.surfaceSecondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tokens.colors.borderDefault.withValues(alpha: 0.5),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent bar skeleton
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: tokens.colors.surfaceTertiary,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: icon + title + chip
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        // Icon skeleton
                        LoadingShimmerBox(
                          width: 36,
                          height: 36,
                          borderRadius:
                              BorderRadius.all(Radius.circular(10)),
                        ),
                        SizedBox(width: AppSpacing.md),
                        // Title skeleton
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LoadingShimmerBox(width: 180, height: 14),
                              SizedBox(height: 6),
                              LoadingShimmerBox(width: 120, height: 14),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        // Chip skeleton
                        LoadingShimmerBox(
                          width: 52,
                          height: 20,
                          borderRadius:
                              BorderRadius.all(Radius.circular(8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Metadata row skeleton
                    const Row(
                      children: [
                        LoadingShimmerBox(width: 70, height: 10),
                        SizedBox(width: AppSpacing.md),
                        LoadingShimmerBox(width: 60, height: 10),
                        SizedBox(width: AppSpacing.md),
                        LoadingShimmerBox(width: 50, height: 10),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
