import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/shared/widgets/accessibility_focus_ring.dart';
import 'package:flutter/material.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    required this.controller,
    required this.onChanged,
    required this.onSend,
    required this.isSending,
    this.enabled = true,
    this.hintText,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final bool isSending;
  final bool enabled;
  final String? hintText;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focusNode;
  late final AnimationController _focusController;
  late final Animation<double> _focusAnim;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(() {
        final focused = _focusNode.hasFocus;
        if (focused != _isFocused) {
          setState(() => _isFocused = focused);
          if (focused) {
            _focusController.forward();
          } else {
            _focusController.reverse();
          }
        }
      });

    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _focusAnim = CurvedAnimation(
      parent: _focusController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _focusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final canSend =
            widget.enabled && value.text.trim().isNotEmpty && !widget.isSending;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Gradient fade above the bar ─────────────────────────
            IgnorePointer(
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      tokens.colors.surfacePrimary.withValues(alpha: 0),
                      tokens.colors.surfacePrimary.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),

            // ── Input capsule ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: AnimatedBuilder(
                animation: _focusAnim,
                builder: (context, child) {
                  final glowAlpha = _focusAnim.value * 0.18;
                  final borderAlpha = 0.25 + _focusAnim.value * 0.5;

                  return Container(
                    key: const Key('chat-input-bar'),
                    decoration: BoxDecoration(
                      color: tokens.colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: tokens.colors.accentPrimary.withValues(
                          alpha: borderAlpha,
                        ),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: tokens.colors.accentPrimary.withValues(
                            alpha: glowAlpha,
                          ),
                          blurRadius: 16,
                          spreadRadius: -2,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // ── Text field ────────────────────────────────
                    Expanded(
                      child: TextField(
                        key: const Key('chat-input-text-field'),
                        controller: widget.controller,
                        focusNode: _focusNode,
                        enabled: widget.enabled,
                        minLines: 1,
                        maxLines: 5,
                        onChanged: widget.onChanged,
                        textInputAction: TextInputAction.newline,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          color: Theme.of(context).extension<DocuMindTokens>()!
                              .colors
                              .textPrimary,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.hintText ?? 'Ask this document a question…',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context)
                                .extension<DocuMindTokens>()!
                                .colors
                                .textTertiary,
                            height: 1.4,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                        ),
                      ),
                    ),

                    // ── Send button ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(
                        right: 8,
                        bottom: 8,
                      ),
                      child: Semantics(
                        button: true,
                        enabled: canSend,
                        label: canSend
                            ? 'Send question'
                            : 'Send question, disabled',
                        child: AccessibilityFocusRing(
                          key: const Key('chat-send-focus-ring'),
                          borderRadius: 20,
                          child: AnimatedScale(
                            scale: canSend ? 1.0 : 0.88,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            child: GestureDetector(
                              onTap: canSend ? widget.onSend : null,
                              child: AnimatedContainer(
                                key: const Key('chat-send-button'),
                                duration: const Duration(milliseconds: 200),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: canSend
                                      ? LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Theme.of(context)
                                                .extension<DocuMindTokens>()!
                                                .colors
                                                .accentPrimary,
                                            const Color(0xFFD63D13),
                                          ],
                                        )
                                      : null,
                                  color: canSend
                                      ? null
                                      : Theme.of(context)
                                            .extension<DocuMindTokens>()!
                                            .colors
                                            .surfaceTertiary,
                                  boxShadow: canSend
                                      ? [
                                          BoxShadow(
                                            color: Theme.of(context)
                                                .extension<DocuMindTokens>()!
                                                .colors
                                                .accentPrimary
                                                .withValues(alpha: 0.4),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: widget.isSending
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Theme.of(context)
                                                .extension<DocuMindTokens>()!
                                                .colors
                                                .textOnAccent,
                                          ),
                                        )
                                      : ExcludeSemantics(
                                          child: Icon(
                                            Icons.arrow_upward_rounded,
                                            size: 20,
                                            color: canSend
                                                ? Colors.white
                                                : Theme.of(context)
                                                      .extension<
                                                        DocuMindTokens
                                                      >()!
                                                      .colors
                                                      .textTertiary,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
