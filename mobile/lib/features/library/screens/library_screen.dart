import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:documind_ai/features/library/providers/document_list_provider.dart';
import 'package:documind_ai/features/library/providers/document_upload_controller.dart';
import 'package:documind_ai/features/library/widgets/document_card.dart';
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
    final documentsAsync = ref.watch(documentListProvider);

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
      body: RefreshIndicator(
        onRefresh: () => ref.read(documentListProvider.notifier).refresh(),
        child: documentsAsync.when(
          data: (response) => _LibraryContent(
            documents: response.items,
            uploadState: uploadState,
            onUploadTap: () {
              ref
                  .read(documentUploadControllerProvider.notifier)
                  .pickAndUpload();
            },
            onUploadRetry: () {
              ref.read(documentUploadControllerProvider.notifier).retryUpload();
            },
            onUploadReadyTap: uploadState.uploadedDocument == null
                ? null
                : () {
                    context.go('/chat/${uploadState.uploadedDocument!.id}');
                  },
            onDocumentTap: (document) {
              context.go('/chat/${document.id}');
            },
            onDocumentLongPress: (document) {
              _showDocumentActions(context, ref, document);
            },
          ),
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: CircularProgressIndicator(
                  color: tokens.colors.accentPrimary,
                ),
              ),
            ],
          ),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Unable to load documents right now.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: tokens.colors.accentError,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () {
                  ref.read(documentListProvider.notifier).refresh();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDocumentActions(
    BuildContext context,
    WidgetRef ref,
    UploadedDocument document,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(
        context,
      ).extension<DocuMindTokens>()!.colors.surfaceSecondary,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: Key('document-card-menu-info-${document.id}'),
                minVerticalPadding: AppSpacing.md,
                minTileHeight: 44,
                leading: const Icon(Icons.info_outline),
                title: const Text('Info'),
                onTap: () => Navigator.of(sheetContext).pop('info'),
              ),
              ListTile(
                key: Key('document-card-menu-delete-${document.id}'),
                minVerticalPadding: AppSpacing.md,
                minTileHeight: 44,
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            ],
          ),
        );
      },
    );

    if (!context.mounted) {
      return;
    }

    if (action == 'info') {
      await _showInfoDialog(context, document);
      return;
    }
    if (action == 'delete') {
      await _confirmAndDelete(context, ref, document);
    }
  }

  Future<void> _showInfoDialog(
    BuildContext context,
    UploadedDocument document,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Document info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Title: ${document.title}'),
              Text('Status: ${document.status}'),
              Text('Created: ${document.createdAt.toIso8601String()}'),
              Text('Pages: ${document.pageCount}'),
              Text('File size: ${document.fileSize} bytes'),
              if (document.errorMessage != null)
                Text('Error: ${document.errorMessage!}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    UploadedDocument document,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete document?'),
          content: Text('This will permanently remove "${document.title}".'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirm-delete-document-button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    final tokens = Theme.of(context).extension<DocuMindTokens>()!;
    final api = ref.read(documentsApiProvider);

    try {
      await api.deleteDocument(document.id);
      await ref.read(documentListProvider.notifier).refresh();
    } on LibraryApiError catch (error) {
      final isNotFound =
          error.code == 'DOCUMENT_NOT_FOUND' ||
          error.code == 'NOT_FOUND' ||
          error.message.toLowerCase().contains('not found');

      if (isNotFound) {
        await ref.read(documentListProvider.notifier).refresh();
      }

      if (!context.mounted) {
        return;
      }

      final message = isNotFound ? 'Document not found.' : error.message;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: tokens.colors.accentError,
          ),
        );
    }
  }
}

class _LibraryContent extends StatelessWidget {
  const _LibraryContent({
    required this.documents,
    required this.uploadState,
    required this.onUploadTap,
    required this.onUploadRetry,
    required this.onUploadReadyTap,
    required this.onDocumentTap,
    required this.onDocumentLongPress,
  });

  final List<UploadedDocument> documents;
  final DocumentUploadState uploadState;
  final VoidCallback onUploadTap;
  final VoidCallback onUploadRetry;
  final VoidCallback? onUploadReadyTap;
  final void Function(UploadedDocument document) onDocumentTap;
  final void Function(UploadedDocument document) onDocumentLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final showUploadCard = uploadState.phase != UploadCardPhase.idle;
    final isEmpty = documents.isEmpty && !showUploadCard;

    if (isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SizedBox(height: AppSpacing.x2l),
          Icon(
            Icons.picture_as_pdf_outlined,
            size: 56,
            color: tokens.colors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Upload your first PDF',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: tokens.colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your documents will appear here once uploaded.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Semantics(
              button: true,
              label: 'Upload your first PDF',
              child: FilledButton.icon(
                key: const Key('library-empty-upload-cta'),
                onPressed: onUploadTap,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload PDF'),
              ),
            ),
          ),
        ],
      );
    }

    final itemCount = documents.length + (showUploadCard ? 1 : 0);
    return ListView.builder(
      key: const Key('library-document-list'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showUploadCard && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: DocumentUploadCard(
              state: uploadState,
              onRetry: onUploadRetry,
              onReadyTap: onUploadReadyTap,
            ),
          );
        }

        final documentIndex = showUploadCard ? index - 1 : index;
        final document = documents[documentIndex];

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Hero(
            tag: 'document-${document.id}',
            child: DocumentCard(
              document: document,
              onTap: () => onDocumentTap(document),
              onLongPress: () => onDocumentLongPress(document),
            ),
          ),
        );
      },
    );
  }
}
