import 'dart:math' as math;

import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// An animated "floating documents" composition for the library empty state.
///
/// Shows 3 layered card shapes with gentle parallax rotation driven by
/// a time-based auto-animation, plus a soft glow behind them.
class FloatingDocumentsAnimation extends StatefulWidget {
  const FloatingDocumentsAnimation({super.key});

  @override
  State<FloatingDocumentsAnimation> createState() =>
      _FloatingDocumentsAnimationState();
}

class _FloatingDocumentsAnimationState extends State<FloatingDocumentsAnimation>
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
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;
    final controller = _controller;

    if (controller == null) {
      return _buildStaticComposition(tokens);
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return _buildAnimatedComposition(tokens, t);
      },
    );
  }

  Widget _buildStaticComposition(DocuMindTokens tokens) {
    return SizedBox(
      width: 200,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildGlow(tokens, 0.3),
          _buildCard(tokens, index: 0, rotation: -0.12, offset: const Offset(-16, 8)),
          _buildCard(tokens, index: 1, rotation: 0.08, offset: const Offset(12, -4)),
          _buildCard(tokens, index: 2, rotation: -0.02, offset: Offset.zero),
        ],
      ),
    );
  }

  Widget _buildAnimatedComposition(DocuMindTokens tokens, double t) {
    // Three different phase-shifted sine waves for organic motion
    final wave1 = math.sin(t * 2 * math.pi);
    final wave2 = math.sin(t * 2 * math.pi + (2 * math.pi / 3));
    final wave3 = math.sin(t * 2 * math.pi + (4 * math.pi / 3));

    // Glow pulsation
    final glowAlpha = 0.2 + (wave1 * 0.1);

    return SizedBox(
      width: 200,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildGlow(tokens, glowAlpha),
          _buildCard(
            tokens,
            index: 0,
            rotation: -0.12 + (wave1 * 0.03),
            offset: Offset(-16 + (wave2 * 3), 8 + (wave1 * 4)),
          ),
          _buildCard(
            tokens,
            index: 1,
            rotation: 0.08 + (wave2 * 0.025),
            offset: Offset(12 + (wave3 * 3), -4 + (wave2 * 3)),
          ),
          _buildCard(
            tokens,
            index: 2,
            rotation: -0.02 + (wave3 * 0.02),
            offset: Offset(wave1 * 2, wave3 * 3),
          ),
        ],
      ),
    );
  }

  Widget _buildGlow(DocuMindTokens tokens, double alpha) {
    return Positioned.fill(
      child: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                tokens.colors.accentAiGlow.withValues(alpha: alpha),
                tokens.colors.accentPrimary.withValues(alpha: alpha * 0.4),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    DocuMindTokens tokens, {
    required int index,
    required double rotation,
    required Offset offset,
  }) {
    // Each card gets progressively brighter and slightly different size
    final sizes = [
      const Size(100, 70),
      const Size(108, 74),
      const Size(116, 78),
    ];
    final alphas = [0.35, 0.55, 0.85];
    final size = sizes[index];
    final alpha = alphas[index];

    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            color: tokens.colors.surfaceSecondary.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: tokens.colors.borderDefault.withValues(alpha: alpha * 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fake title line
                Container(
                  width: size.width * 0.65,
                  height: 6,
                  decoration: BoxDecoration(
                    color: tokens.colors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 6),
                // Fake body lines
                Container(
                  width: size.width * 0.85,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.colors.textTertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: size.width * 0.5,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.colors.textTertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                // Fake accent bar at bottom
                Container(
                  width: 20,
                  height: 4,
                  decoration: BoxDecoration(
                    color: index == 2
                        ? tokens.colors.accentPrimary.withValues(alpha: 0.6)
                        : tokens.colors.accentAiGlow.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
