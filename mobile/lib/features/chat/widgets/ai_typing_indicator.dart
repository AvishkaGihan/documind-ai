import 'dart:math' as math;

import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

class AiTypingIndicator extends StatefulWidget {
  const AiTypingIndicator({super.key});

  @override
  State<AiTypingIndicator> createState() => _AiTypingIndicatorState();
}

class _AiTypingIndicatorState extends State<AiTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('ai-typing-indicator'),
        margin: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI avatar
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

            const SizedBox(width: AppSpacing.md),

            // Shimmer bar content
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Shimmer bar
                      _ShimmerBar(
                        controller: _controller,
                        color: tokens.colors.accentAiGlow,
                        disabled: disableAnimations,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Analysing document…',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: tokens.colors.textTertiary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  const _ShimmerBar({
    required this.controller,
    required this.color,
    required this.disabled,
  });

  final AnimationController controller;
  final Color color;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    if (disabled) {
      return Container(
        width: 56,
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: color.withValues(alpha: 0.4),
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;

        return ShaderMask(
          shaderCallback: (bounds) {
            // traveling highlight
            final center = -0.4 + t * 1.8;
            return LinearGradient(
              colors: [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.8),
                color,
                color.withValues(alpha: 0.8),
                color.withValues(alpha: 0.15),
              ],
              stops: [
                math.max(0.0, center - 0.35),
                math.max(0.0, center - 0.1),
                center.clamp(0.0, 1.0),
                math.min(1.0, center + 0.1),
                math.min(1.0, center + 0.35),
              ],
            ).createShader(bounds);
          },
          child: Container(
            width: 56,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
