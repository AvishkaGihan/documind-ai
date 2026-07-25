import 'dart:math' as math;

import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// A widget that wraps its [child] with a sweeping animated gradient border.
///
/// Used to draw attention to processing cards and CTA buttons with a subtle,
/// premium glow effect that rotates around the perimeter.
class AnimatedGradientBorder extends StatefulWidget {
  const AnimatedGradientBorder({
    required this.child,
    this.borderRadius = 20,
    this.strokeWidth = 2.0,
    this.gradientColors,
    this.duration = const Duration(milliseconds: 2400),
    super.key,
  });

  final Widget child;
  final double borderRadius;
  final double strokeWidth;
  final List<Color>? gradientColors;
  final Duration duration;

  @override
  State<AnimatedGradientBorder> createState() => _AnimatedGradientBorderState();
}

class _AnimatedGradientBorderState extends State<AnimatedGradientBorder>
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
      duration: widget.duration,
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

    final colors = widget.gradientColors ??
        [
          tokens.colors.accentAiGlow,
          tokens.colors.accentPrimary,
          tokens.colors.accentAiGlow.withValues(alpha: 0.3),
          tokens.colors.accentPrimary.withValues(alpha: 0.6),
          tokens.colors.accentAiGlow,
        ];

    if (controller == null) {
      // Reduce-motion fallback: static border
      return CustomPaint(
        painter: _GradientBorderPainter(
          angle: 0,
          colors: colors,
          borderRadius: widget.borderRadius,
          strokeWidth: widget.strokeWidth,
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        return CustomPaint(
          painter: _GradientBorderPainter(
            angle: controller.value * 2 * math.pi,
            colors: colors,
            borderRadius: widget.borderRadius,
            strokeWidth: widget.strokeWidth,
          ),
          child: child,
        );
      },
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  _GradientBorderPainter({
    required this.angle,
    required this.colors,
    required this.borderRadius,
    required this.strokeWidth,
  });

  final double angle;
  final List<Color> colors;
  final double borderRadius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rRect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(borderRadius),
    );

    final gradient = SweepGradient(
      startAngle: angle,
      endAngle: angle + 2 * math.pi,
      colors: colors,
      tileMode: TileMode.clamp,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rRect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}
