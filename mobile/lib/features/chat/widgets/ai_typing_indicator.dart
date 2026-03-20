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
      duration: const Duration(milliseconds: 1200),
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
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: tokens.colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.colors.borderDefault),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                final phase = (t + index * 0.2) % 1;
                final wave = disableAnimations
                    ? 0.75
                    : (0.45 + 0.55 * math.sin(phase * math.pi * 2));
                final opacity = wave.clamp(0.2, 1.0);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tokens.colors.accentAiGlow.withValues(
                      alpha: opacity,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: disableAnimations
                        ? null
                        : [
                            BoxShadow(
                              color: tokens.colors.accentAiGlow.withValues(
                                alpha: 0.4 * opacity,
                              ),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
