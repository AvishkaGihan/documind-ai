import 'dart:ui';

import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:documind_ai/features/library/widgets/processing_animation.dart';
import 'package:documind_ai/shared/widgets/accessibility_focus_ring.dart';
import 'package:flutter/material.dart';

class DocumentCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final isReady = document.status == 'ready';
    final isError = document.status == 'error';
    final isProcessing = !isReady && !isError;

    final card = Semantics(
      label:
          'Document ${document.title}. Status ${_statusLabel(document.status)}.',
      button: isReady,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.colors.surfaceSecondary.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: tokens.colors.borderDefault.withValues(alpha: 0.88),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.picture_as_pdf_outlined,
                        color: tokens.colors.accentPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            document.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: tokens.colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${document.pageCount} pages • ${_formatFileSize(document.fileSize)} • ${_formatDate(document.createdAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tokens.colors.textSecondary,
                            ),
                          ),
                          if (isError && document.errorMessage != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              document.errorMessage!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.colors.accentError,
                              ),
                            ),
                          ],
                          if (isProcessing) ...[
                            const SizedBox(height: AppSpacing.sm),
                            ProcessingAnimation(
                              status: document.status,
                              pageCount: document.pageCount,
                              compact: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatusIndicator(status: document.status),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final interactive = AccessibilityFocusRing(
      borderRadius: 18,
      child: InkWell(
        key: Key('document-card-${document.id}'),
        onTap: isReady ? onTap : null,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );

    return interactive;
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

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
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
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    if (status == 'ready') {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: tokens.colors.accentSecondary,
          shape: BoxShape.circle,
        ),
      );
    }

    if (status == 'error') {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: tokens.colors.accentError,
          shape: BoxShape.circle,
        ),
      );
    }

    return SizedBox(
      width: 16,
      height: 16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: tokens.colors.accentAiGlow, width: 2),
        ),
      ),
    );
  }
}
