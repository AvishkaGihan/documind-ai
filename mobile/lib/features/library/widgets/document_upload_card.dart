import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:flutter/material.dart';

class DocumentUploadCard extends StatelessWidget {
  const DocumentUploadCard({required this.state, super.key});

  final DocumentUploadState state;

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

    if (state.phase == UploadCardPhase.processing) {
      return _ProcessingGlowContainer(child: cardContent);
    }

    return cardContent;
  }

  Widget _buildStatusRow(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    switch (state.phase) {
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Processing...',
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
    if (state.phase == UploadCardPhase.uploading) {
      return tokens.colors.accentPrimary;
    }
    return tokens.colors.borderDefault;
  }

  String _semanticsLabel(String title) {
    switch (state.phase) {
      case UploadCardPhase.uploading:
        final progress = state.progress ?? 0;
        return '$title uploading ${progress.toStringAsFixed(0)} percent';
      case UploadCardPhase.processing:
        return '$title uploaded and processing';
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
