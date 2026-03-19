import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:documind_ai/features/library/providers/document_upload_controller.dart';
import 'package:documind_ai/features/library/widgets/document_upload_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final uploadState = ref.watch(documentUploadControllerProvider);

    ref.listen<DocumentUploadState>(documentUploadControllerProvider, (
      previous,
      next,
    ) {
      if (next.announcement != null &&
          next.announcement != previous?.announcement) {
        final textDirection = Directionality.of(context);
        SemanticsService.sendAnnouncement(
          View.of(context),
          next.announcement!,
          textDirection,
        );
        ref.read(documentUploadControllerProvider.notifier).clearAnnouncement();
      }

      final justFailed =
          next.phase == UploadCardPhase.failed &&
          previous?.phase != UploadCardPhase.failed;
      if (justFailed && next.error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(next.error!.message),
              backgroundColor: tokens.colors.accentError,
              duration: const Duration(days: 1),
              action: SnackBarAction(
                label: 'Retry',
                textColor: tokens.colors.textOnAccent,
                onPressed: () {
                  ref
                      .read(documentUploadControllerProvider.notifier)
                      .retryUpload();
                },
              ),
            ),
          );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Document Library')),
      backgroundColor: tokens.colors.surfacePrimary,
      floatingActionButton: Semantics(
        button: true,
        label: 'Upload PDF',
        child: FloatingActionButton(
          key: const Key('library-upload-fab'),
          onPressed: () {
            ref.read(documentUploadControllerProvider.notifier).pickAndUpload();
          },
          tooltip: 'Upload PDF',
          child: const Icon(Icons.add),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ListView(
          children: [
            Text(
              'Upload PDFs and monitor progress in real time.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: tokens.colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (uploadState.phase == UploadCardPhase.idle)
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: tokens.colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.colors.borderDefault),
                ),
                child: Text(
                  'Upload a PDF to get started.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.colors.textSecondary,
                  ),
                ),
              )
            else
              DocumentUploadCard(
                state: uploadState,
                onRetry: () {
                  ref
                      .read(documentUploadControllerProvider.notifier)
                      .retryUpload();
                },
                onReadyTap: uploadState.uploadedDocument == null
                    ? null
                    : () {
                        context.go('/chat/${uploadState.uploadedDocument!.id}');
                      },
              ),
          ],
        ),
      ),
    );
  }
}
