import 'dart:ui';

import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:documind_ai/features/library/widgets/animated_gradient_border.dart';
import 'package:documind_ai/features/library/widgets/processing_animation.dart';
import 'package:flutter/material.dart';

/// A redesigned document card with vertical layout, color-coded accent bar,
/// status chip, rich metadata, and animated processing border.
class DocumentCard extends StatefulWidget {
  const DocumentCard({
    required this.document,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final UploadedDocument document;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  @override
  State<DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<DocumentCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final doc = widget.document;
    final isReady = doc.status == 'ready';
    final isError = doc.status == 'error';
    final isProcessing = !isReady && !isError;

    final accentColor = _accentColor(tokens);

    final cardBody = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.surfaceSecondary.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: isProcessing
                ? null // border handled by AnimatedGradientBorder
                : Border.all(
                    color:
                        tokens.colors.borderDefault.withValues(alpha: 0.88),
                  ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Color-coded accent bar ──
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(20),
                    ),
                  ),
                ),
                // ── Card content ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Top row: icon + title + status chip ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Document type icon
                            _DocumentIcon(accentColor: accentColor),
                            const SizedBox(width: AppSpacing.md),
                            // Title
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      color: tokens.colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            // Status chip
                            _StatusChip(status: doc.status),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // ── Metadata row ──
                        _MetadataRow(document: doc),

                        // ── Error message ──
                        if (isError && doc.errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            doc.errorMessage!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tokens.colors.accentError,
                            ),
                          ),
                        ],

                        // ── Processing animation ──
                        if (isProcessing) ...[
                          const SizedBox(height: AppSpacing.sm),
                          ProcessingAnimation(
                            status: doc.status,
                            pageCount: doc.pageCount,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Wrap processing cards with animated gradient border
    final borderedCard = isProcessing
        ? AnimatedGradientBorder(
            borderRadius: 20,
            strokeWidth: 1.5,
            child: cardBody,
          )
        : cardBody;

    // Handle gestures and drive the press animation
    final interactiveCard = GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        if (isReady && widget.onTap != null) {
          widget.onTap!();
        }
      },
      onTapCancel: () => _pressController.reverse(),
      onLongPress: () {
        _pressController.reverse();
        widget.onLongPress();
      },
      child: borderedCard,
    );

    // Wrap in semantics
    final semanticCard = Semantics(
      label:
          'Document ${doc.title}. Status ${_statusLabel(doc.status)}.',
      button: isReady,
      child: interactiveCard,
    );

    return AnimatedBuilder(
      animation: _scaleAnimation,
      child: semanticCard,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
    );
  }

  /// The accent bar / icon color based on document status.
  Color _accentColor(DocuMindTokens tokens) {
    if (widget.document.status == 'ready') {
      return tokens.colors.accentSecondary;
    }
    if (widget.document.status == 'error') {
      return tokens.colors.accentError;
    }
    return tokens.colors.accentAiGlow;
  }

  String _statusLabel(String status) {
    if (status == 'ready') {
      return 'ready';
    }
    if (status == 'error') {
      return 'error';
    }
    return 'processing';
  }
}

// ─── Document icon with gradient background ─────────────────────────────────

class _DocumentIcon extends StatelessWidget {
  const _DocumentIcon({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withValues(alpha: 0.2),
              accentColor.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          Icons.picture_as_pdf_rounded,
          color: accentColor,
          size: 18,
        ),
      ),
    );
  }
}

// ─── Status chip ────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    Color bgColor;
    Color fgColor;
    String label;

    if (status == 'ready') {
      bgColor = tokens.colors.accentSecondary.withValues(alpha: 0.15);
      fgColor = tokens.colors.accentSecondary;
      label = 'Ready';
    } else if (status == 'error') {
      bgColor = tokens.colors.accentError.withValues(alpha: 0.15);
      fgColor = tokens.colors.accentError;
      label = 'Error';
    } else {
      bgColor = tokens.colors.accentAiGlow.withValues(alpha: 0.15);
      fgColor = tokens.colors.accentAiGlow;
      label = 'Processing';
    }

    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: fgColor,
            letterSpacing: 0.3,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

// ─── Metadata row with icons ────────────────────────────────────────────────

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.document});

  final UploadedDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: tokens.colors.textSecondary,
      fontSize: 11,
      height: 1.3,
    );
    final iconColor = tokens.colors.textTertiary;
    const iconSize = 12.0;

    return ExcludeSemantics(
      child: Row(
        children: [
          Icon(Icons.auto_stories_outlined, size: iconSize, color: iconColor),
          const SizedBox(width: 3),
          Text('${document.pageCount} pages', style: metaStyle),
          _dot(tokens),
          Icon(Icons.sd_storage_outlined, size: iconSize, color: iconColor),
          const SizedBox(width: 3),
          Text(_formatFileSize(document.fileSize), style: metaStyle),
          _dot(tokens),
          Icon(Icons.access_time_outlined, size: iconSize, color: iconColor),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              _formatRelativeTime(document.createdAt),
              style: metaStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(DocuMindTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: tokens.colors.textTertiary.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inMinutes < 60) {
      final m = difference.inMinutes;
      return '$m min${m == 1 ? '' : 's'} ago';
    }
    if (difference.inHours < 24) {
      final h = difference.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    }
    if (difference.inDays < 7) {
      final d = difference.inDays;
      return '$d day${d == 1 ? '' : 's'} ago';
    }
    if (difference.inDays < 30) {
      final w = (difference.inDays / 7).floor();
      return '$w week${w == 1 ? '' : 's'} ago';
    }
    if (difference.inDays < 365) {
      final m = (difference.inDays / 30).floor();
      return '$m month${m == 1 ? '' : 's'} ago';
    }
    final y = (difference.inDays / 365).floor();
    return '$y year${y == 1 ? '' : 's'} ago';
  }
}
