import 'dart:math' as math;

import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

class ChatEmptyState extends StatefulWidget {
  const ChatEmptyState({
    required this.documentTitle,
    this.onSuggestionTap,
    this.onSelectDocument,
    super.key,
  });

  final String documentTitle;
  final ValueChanged<String>? onSuggestionTap;
  final VoidCallback? onSelectDocument;

  @override
  State<ChatEmptyState> createState() => _ChatEmptyStateState();
}

class _ChatEmptyStateState extends State<ChatEmptyState>
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final AnimationController _rotateController;
  late final AnimationController _entryController;

  late final Animation<double> _breathAnim;
  late final Animation<double> _entryAnim;

  static const _suggestions = [
    'Summarize the key points',
    'What are the main arguments?',
    'Find any contradictions',
    'What conclusions are drawn?',
    'List the key facts',
  ];

  @override
  void initState() {
    super.initState();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _breathAnim = CurvedAnimation(
      parent: _breathController,
      curve: Curves.easeInOut,
    );

    _entryAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _breathController.dispose();
    _rotateController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight + AppSpacing.lg;

    return FadeTransition(
      opacity: _entryAnim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(_entryAnim),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            topInset,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.md),

              // ── Animated orb ──────────────────────────────────────────
              SizedBox(
                width: 128,
                height: 128,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer rotating ring
                    if (!disableAnimations)
                      AnimatedBuilder(
                        animation: _rotateController,
                        builder: (context, _) {
                          return Transform.rotate(
                            angle: _rotateController.value * 2 * math.pi,
                            child: CustomPaint(
                              size: const Size(128, 128),
                              painter: _RingPainter(
                                color: tokens.colors.accentPrimary,
                              ),
                            ),
                          );
                        },
                      ),

                    // Breathing glow
                    AnimatedBuilder(
                      animation: disableAnimations
                          ? kAlwaysCompleteAnimation
                          : _breathAnim,
                      builder: (context, _) {
                        final t = disableAnimations ? 0.5 : _breathAnim.value;
                        final glowSize = 84 + (t * 12);
                        return Container(
                          width: glowSize,
                          height: glowSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                tokens.colors.accentPrimary.withValues(
                                  alpha: 0.35 + t * 0.15,
                                ),
                                tokens.colors.accentAiGlow.withValues(
                                  alpha: 0.15 + t * 0.08,
                                ),
                                tokens.colors.surfacePrimary.withValues(
                                  alpha: 0,
                                ),
                              ],
                              stops: const [0.0, 0.55, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: tokens.colors.accentPrimary.withValues(
                                  alpha: 0.3 + t * 0.2,
                                ),
                                blurRadius: 28 + t * 12,
                                spreadRadius: 3 + t * 3,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Center icon
                    Container(
                      width: 54,
                      height: 54,
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
                            color: tokens.colors.accentPrimary.withValues(
                              alpha: 0.5,
                            ),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '✦',
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Document title ────────────────────────────────────────
              Text(
                widget.onSelectDocument != null ||
                        widget.documentTitle.isEmpty ||
                        widget.documentTitle == 'No Document Selected'
                    ? 'No Document Selected'
                    : widget.documentTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: tokens.colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppSpacing.xs),

              Text(
                widget.onSelectDocument != null ||
                        widget.documentTitle == 'No Document Selected'
                    ? 'Select a document from your library to start asking questions.'
                    : 'Ask anything about this document',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.colors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xl),

              if (widget.onSelectDocument != null) ...[
                FilledButton.icon(
                  key: const Key('chat-select-document-button'),
                  onPressed: widget.onSelectDocument,
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Select Document'),
                ),
              ] else if (widget.onSuggestionTap != null) ...[
                // ── Suggestion chips ──────────────────────────────────────
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _suggestions.map((suggestion) {
                    return _SuggestionChip(
                      text: suggestion,
                      tokens: tokens,
                      onTap: () => widget.onSuggestionTap?.call(suggestion),
                    );
                  }).toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Suggestion chip ─────────────────────────────────────────────────────────

class _SuggestionChip extends StatefulWidget {
  const _SuggestionChip({
    required this.text,
    required this.tokens,
    required this.onTap,
  });

  final String text;
  final DocuMindTokens tokens;
  final VoidCallback onTap;

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.tokens.colors;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceTertiary.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.accentPrimary.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.accentPrimary.withValues(alpha: 0.06),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: colors.accentPrimary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Custom painter for rotating ring ─────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const segments = 12;
    const segmentAngle = (2 * math.pi) / segments;

    for (var i = 0; i < segments; i++) {
      final opacity = (i / segments) * 0.6;
      paint.color = color.withValues(alpha: opacity);
      final startAngle = i * segmentAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.color != color;
}
