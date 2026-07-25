import 'dart:ui';

import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:documind_ai/features/library/widgets/animated_gradient_border.dart';
import 'package:documind_ai/features/library/widgets/processing_animation.dart';
import 'package:flutter/material.dart';

/// Upload card redesigned to match the new document card style.
///
/// Uses the same accent-bar layout, glassmorphic backdrop, and status chip
/// pattern as [DocumentCard] for visual consistency.
class DocumentUploadCard extends StatelessWidget {
  const DocumentUploadCard({
    required this.state,
    this.onReadyTap,
    this.onRetry,
    super.key,
  });

  final DocumentUploadState state;
  final VoidCallback? onReadyTap;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final title =
        state.uploadedDocument?.title ?? state.selectedFile?.name ?? 'Document';

    final accentColor = _accentColor(tokens);
    final isProcessingPhase = state.phase == UploadCardPhase.processing ||
        state.phase == UploadCardPhase.uploading;

    final cardContent = Semantics(
      liveRegion: true,
      label: _semanticsLabel(title),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.surfaceSecondary.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(20),
              border: isProcessingPhase
                  ? null
                  : Border.all(
                      color: _borderColor(tokens),
                    ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Accent bar ──
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(20),
                      ),
                    ),
                  ),
                  // ── Content ──
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Icon
                              _UploadIcon(accentColor: accentColor),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      theme.textTheme.titleMedium?.copyWith(
                                    color: tokens.colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _UploadStatusChip(phase: state.phase),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _buildStatusContent(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Wrap processing/uploading in animated border
    final borderedCard = isProcessingPhase
        ? AnimatedGradientBorder(
            borderRadius: 20,
            strokeWidth: 1.5,
            child: cardContent,
          )
        : cardContent;

    final canOpenChat =
        state.phase == UploadCardPhase.ready && onReadyTap != null;
    final wrappedCard = canOpenChat
        ? InkWell(
            key: const Key('document-ready-tap-target'),
            onTap: onReadyTap,
            borderRadius: BorderRadius.circular(20),
            child: borderedCard,
          )
        : borderedCard;

    if (state.phase == UploadCardPhase.ready) {
      return _ReadyCelebrationContainer(child: wrappedCard);
    }

    return wrappedCard;
  }

  Widget _buildStatusContent(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    switch (state.phase) {
      case UploadCardPhase.queued:
        return Row(
          children: [
            Icon(Icons.schedule_rounded, size: 16,
                color: tokens.colors.accentPrimary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Queued — will upload when online',
                key: const Key('upload-queued-label'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      case UploadCardPhase.uploading:
        final progress = state.progress ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                key: const Key('upload-progress-indicator'),
                minHeight: 4,
                value: progress / 100,
                backgroundColor: tokens.colors.surfaceTertiary,
                valueColor: AlwaysStoppedAnimation<Color>(
                  tokens.colors.accentPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Uploading ${progress.toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.colors.textSecondary,
              ),
            ),
          ],
        );
      case UploadCardPhase.processing:
        final doc = state.uploadedDocument;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProcessingAnimation(
              key: const Key('upload-processing-label'),
              status: doc?.status ?? 'processing',
              pageCount: doc?.pageCount,
            ),
            if (doc != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.sd_storage_outlined, size: 12,
                      color: tokens.colors.textTertiary),
                  const SizedBox(width: 3),
                  Text(
                    _formatFileSize(doc.fileSize),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Icon(Icons.auto_stories_outlined, size: 12,
                      color: tokens.colors.textTertiary),
                  const SizedBox(width: 3),
                  Text(
                    '${doc.pageCount} pages',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      case UploadCardPhase.ready:
        return Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 16,
                color: tokens.colors.accentSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Ready to answer your questions!',
                key: const Key('upload-ready-label'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.colors.accentSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18,
                color: tokens.colors.textSecondary),
          ],
        );
      case UploadCardPhase.processingError:
        final message =
            state.uploadedDocument?.errorMessage ??
            'Processing failed. Please try uploading again.';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_rounded, size: 16,
                    color: tokens.colors.accentError),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    key: const Key('processing-error-label'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.colors.accentError,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: const Key('processing-retry-button'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        );
      case UploadCardPhase.failed:
        return Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 16,
                color: tokens.colors.accentError),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                state.error?.message ?? 'Upload failed. Try again.',
                key: const Key('upload-error-label'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.colors.accentError,
                ),
              ),
            ),
          ],
        );
      case UploadCardPhase.idle:
        return Text('Ready to upload.',
            style: Theme.of(context).textTheme.bodySmall);
    }
  }

  Color _accentColor(DocuMindTokens tokens) {
    switch (state.phase) {
      case UploadCardPhase.ready:
        return tokens.colors.accentSecondary;
      case UploadCardPhase.failed:
      case UploadCardPhase.processingError:
        return tokens.colors.accentError;
      case UploadCardPhase.uploading:
      case UploadCardPhase.processing:
        return tokens.colors.accentAiGlow;
      case UploadCardPhase.queued:
        return tokens.colors.accentPrimary;
      case UploadCardPhase.idle:
        return tokens.colors.accentSecondary;
    }
  }

  Color _borderColor(DocuMindTokens tokens) {
    if (state.phase == UploadCardPhase.failed ||
        state.phase == UploadCardPhase.processingError) {
      return tokens.colors.accentError.withValues(alpha: 0.6);
    }
    if (state.phase == UploadCardPhase.ready) {
      return tokens.colors.accentSecondary.withValues(alpha: 0.5);
    }
    return tokens.colors.borderDefault.withValues(alpha: 0.88);
  }

  String _semanticsLabel(String title) {
    switch (state.phase) {
      case UploadCardPhase.queued:
        return '$title queued for upload';
      case UploadCardPhase.uploading:
        final progress = state.progress ?? 0;
        return '$title uploading ${progress.toStringAsFixed(0)} percent';
      case UploadCardPhase.processing:
        return '$title uploaded and processing';
      case UploadCardPhase.ready:
        return '$title ready for chat';
      case UploadCardPhase.processingError:
        return '$title processing failed';
      case UploadCardPhase.failed:
        return '$title upload failed';
      case UploadCardPhase.idle:
        return '$title ready';
    }
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

// ─── Upload icon ────────────────────────────────────────────────────────────

class _UploadIcon extends StatelessWidget {
  const _UploadIcon({required this.accentColor});

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
          Icons.upload_file_rounded,
          color: accentColor,
          size: 18,
        ),
      ),
    );
  }
}

// ─── Upload status chip ─────────────────────────────────────────────────────

class _UploadStatusChip extends StatelessWidget {
  const _UploadStatusChip({required this.phase});

  final UploadCardPhase phase;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    Color bgColor;
    Color fgColor;
    String label;

    switch (phase) {
      case UploadCardPhase.queued:
        bgColor = tokens.colors.accentPrimary.withValues(alpha: 0.15);
        fgColor = tokens.colors.accentPrimary;
        label = 'Queued';
      case UploadCardPhase.uploading:
        bgColor = tokens.colors.accentPrimary.withValues(alpha: 0.15);
        fgColor = tokens.colors.accentPrimary;
        label = 'Uploading';
      case UploadCardPhase.processing:
        bgColor = tokens.colors.accentAiGlow.withValues(alpha: 0.15);
        fgColor = tokens.colors.accentAiGlow;
        label = 'Processing';
      case UploadCardPhase.ready:
        bgColor = tokens.colors.accentSecondary.withValues(alpha: 0.15);
        fgColor = tokens.colors.accentSecondary;
        label = 'Ready';
      case UploadCardPhase.processingError:
      case UploadCardPhase.failed:
        bgColor = tokens.colors.accentError.withValues(alpha: 0.15);
        fgColor = tokens.colors.accentError;
        label = 'Error';
      case UploadCardPhase.idle:
        bgColor = tokens.colors.accentSecondary.withValues(alpha: 0.15);
        fgColor = tokens.colors.accentSecondary;
        label = 'Idle';
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

// ─── Ready celebration container ────────────────────────────────────────────

class _ReadyCelebrationContainer extends StatefulWidget {
  const _ReadyCelebrationContainer({required this.child});

  final Widget child;

  @override
  State<_ReadyCelebrationContainer> createState() =>
      _ReadyCelebrationContainerState();
}

class _ReadyCelebrationContainerState extends State<_ReadyCelebrationContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return widget.child;
    }

    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_controller.value);
        final glow = (1 - t).clamp(0, 1).toDouble();
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: tokens.colors.accentSecondary.withValues(
                  alpha: 0.40 * glow,
                ),
                blurRadius: 8 + (12 * glow),
                spreadRadius: 0.2 + glow,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
