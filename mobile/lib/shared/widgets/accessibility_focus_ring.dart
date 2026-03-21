import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

class AccessibilityFocusRing extends StatefulWidget {
  const AccessibilityFocusRing({
    required this.child,
    this.borderRadius = 12,
    this.padding = EdgeInsets.zero,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<AccessibilityFocusRing> createState() => _AccessibilityFocusRingState();
}

class _AccessibilityFocusRingState extends State<AccessibilityFocusRing> {
  bool _showFocusHighlight = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onShowFocusHighlight: (showHighlight) {
        if (_showFocusHighlight == showHighlight) {
          return;
        }
        setState(() {
          _showFocusHighlight = showHighlight;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: _showFocusHighlight
                ? tokens.colors.accentPrimary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
