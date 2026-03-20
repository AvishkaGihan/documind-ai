import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:flutter/material.dart';

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

    final cardContent = Semantics(
      liveRegion: true,
      label: _semanticsLabel(title),
      child: Container(
        key: const Key('document-upload-card'),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: tokens.colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor(tokens)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: tokens.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildStatusRow(context),
          ],
        ),
      ),
    );

    final canOpenChat =
        state.phase == UploadCardPhase.ready && onReadyTap != null;
    final wrappedCard = canOpenChat
        ? InkWell(
            key: const Key('document-ready-tap-target'),
            onTap: onReadyTap,
            borderRadius: BorderRadius.circular(12),
            child: cardContent,
          )
        : cardContent;

    if (state.phase == UploadCardPhase.processing) {
      return _ProcessingGlowContainer(child: wrappedCard);
    }
    if (state.phase == UploadCardPhase.ready) {
      return _ReadyCelebrationContainer(child: wrappedCard);
    }

    return wrappedCard;
  }

  Widget _buildStatusRow(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    switch (state.phase) {
      case UploadCardPhase.queued:
        return Row(
          children: [
            Icon(Icons.schedule, color: tokens.colors.accentPrimary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Queued - will upload when online',
                key: const Key('upload-queued-label'),
                style: theme.textTheme.bodyMedium?.copyWith(
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
            LinearProgressIndicator(
              key: const Key('upload-progress-indicator'),
              value: progress / 100,
              backgroundColor: tokens.colors.surfaceTertiary,
              valueColor: AlwaysStoppedAnimation<Color>(
                tokens.colors.accentPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Uploading ${progress.toStringAsFixed(0)}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.colors.textSecondary,
              ),
            ),
          ],
        );
      case UploadCardPhase.processing:
        final doc = state.uploadedDocument;
        final stage = _stageLabelForStatus(doc?.status, doc?.pageCount ?? 0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stage,
              key: const Key('upload-processing-label'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.colors.accentAiGlow,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (doc != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'File size: ${_formatFileSize(doc.fileSize)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.colors.textSecondary,
                ),
              ),
              Text(
                'Pages: ${doc.pageCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.colors.textSecondary,
                ),
              ),
            ],
          ],
        );
      case UploadCardPhase.ready:
        return Row(
          children: [
            Icon(Icons.check_circle, color: tokens.colors.accentSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '✅ Ready to answer your questions!',
                key: const Key('upload-ready-label'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.colors.accentSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: tokens.colors.textSecondary),
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
                Icon(Icons.error, color: tokens.colors.accentError),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    key: const Key('processing-error-label'),
                    style: theme.textTheme.bodyMedium?.copyWith(
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
            Icon(Icons.error_outline, color: tokens.colors.accentError),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                state.error?.message ?? 'Upload failed. Try again.',
                key: const Key('upload-error-label'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.colors.accentError,
                ),
              ),
            ),
          ],
        );
      case UploadCardPhase.idle:
        return Text('Ready to upload.', style: theme.textTheme.bodyMedium);
    }
  }

  Color _borderColor(DocuMindTokens tokens) {
    if (state.phase == UploadCardPhase.failed) {
      return tokens.colors.accentError;
    }
    if (state.phase == UploadCardPhase.processingError) {
      return tokens.colors.accentError;
    }
    if (state.phase == UploadCardPhase.ready) {
      return tokens.colors.accentSecondary;
    }
    if (state.phase == UploadCardPhase.uploading) {
      return tokens.colors.accentPrimary;
    }
    return tokens.colors.borderDefault;
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

  String _stageLabelForStatus(String? status, int pageCount) {
    switch (status) {
      case 'extracting':
        if (pageCount > 0) {
          return '📖 Extracting text... ($pageCount pages)';
        }
        return '📖 Extracting text...';
      case 'chunking':
        return '🧩 Creating knowledge chunks...';
      case 'embedding':
        return '🧠 Building intelligence index...';
      default:
        return 'Processing...';
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

class _ProcessingGlowContainer extends StatefulWidget {
  const _ProcessingGlowContainer({required this.child});

  final Widget child;

  @override
  State<_ProcessingGlowContainer> createState() =>
      _ProcessingGlowContainerState();
}

class _ProcessingGlowContainerState extends State<_ProcessingGlowContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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
        final t = Curves.easeInOut.transform(_controller.value);
        final blur = 8 + (t * 8);
        final spread = 0.5 + (t * 1.5);
        final glowColor = Color.lerp(
          tokens.colors.accentAiGlow.withValues(alpha: 0.25),
          tokens.colors.accentAiGlow.withValues(alpha: 0.65),
          t,
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: glowColor ?? tokens.colors.accentAiGlow,
                blurRadius: blur,
                spreadRadius: spread,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

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
            borderRadius: BorderRadius.circular(12),
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
