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

enum LibrarySortMode { date, name, status }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _isSearching = false;
  String _searchQuery = '';
  LibrarySortMode _sortMode = LibrarySortMode.date;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final uploadState = ref.watch(documentUploadControllerProvider);
    final documentsAsync = ref.watch(documentListProvider);
    final isSearching = _isSearching;
    final searchQuery = _searchQuery;
    final sortMode = _sortMode;

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
      appBar: AppBar(
        title: const Text('Document Library'),
        actions: [
          Semantics(
            button: true,
            label: isSearching ? 'Close search' : 'Search documents',
            child: IconButton(
              key: const Key('library-search-button'),
              tooltip: isSearching ? 'Close search' : 'Search',
              onPressed: () {
                if (isSearching) {
                  setState(() {
                    _searchQuery = '';
                    _isSearching = false;
                  });
                  _searchController.clear();
                  return;
                }
                setState(() {
                  _isSearching = true;
                });
              },
              icon: Icon(isSearching ? Icons.close : Icons.search),
            ),
          ),
          Semantics(
            button: true,
            label: 'Sort documents',
            child: IconButton(
              key: const Key('library-sort-button'),
              tooltip: 'Sort',
              onPressed: () async {
                final selected = await _showSortOptions(context, sortMode);
                if (selected != null && context.mounted) {
                  setState(() {
                    _sortMode = selected;
                  });
                }
              },
              icon: const Icon(Icons.sort),
            ),
          ),
        ],
      ),
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
          data: (response) {
            final visibleDocuments = _applySearchAndSort(
              response.items,
              searchQuery,
              sortMode,
            );

            return _LibraryContent(
              documents: visibleDocuments,
              hasAnyDocuments: response.items.isNotEmpty,
              isSearching: isSearching,
              searchQuery: searchQuery,
              onSearchQueryChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              searchController: _searchController,
              onClearSearch: () {
                setState(() {
                  _searchQuery = '';
                });
                _searchController.clear();
              },
              onCloseSearch: () {
                setState(() {
                  _searchQuery = '';
                  _isSearching = false;
                });
                _searchController.clear();
              },
              uploadState: uploadState,
              onUploadTap: () {
                ref
                    .read(documentUploadControllerProvider.notifier)
                    .pickAndUpload();
              },
              onUploadRetry: () {
                ref
                    .read(documentUploadControllerProvider.notifier)
                    .retryUpload();
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
            );
          },
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

  Future<LibrarySortMode?> _showSortOptions(
    BuildContext context,
    LibrarySortMode currentMode,
  ) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;
    return showModalBottomSheet<LibrarySortMode>(
      context: context,
      backgroundColor: tokens.colors.surfaceSecondary,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('library-sort-date'),
                minTileHeight: 44,
                minVerticalPadding: AppSpacing.md,
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Date (newest first)'),
                trailing: currentMode == LibrarySortMode.date
                    ? const Icon(Icons.check)
                    : null,
                onTap: () =>
                    Navigator.of(sheetContext).pop(LibrarySortMode.date),
              ),
              ListTile(
                key: const Key('library-sort-name'),
                minTileHeight: 44,
                minVerticalPadding: AppSpacing.md,
                leading: const Icon(Icons.sort_by_alpha_outlined),
                title: const Text('Name (A-Z)'),
                trailing: currentMode == LibrarySortMode.name
                    ? const Icon(Icons.check)
                    : null,
                onTap: () =>
                    Navigator.of(sheetContext).pop(LibrarySortMode.name),
              ),
              ListTile(
                key: const Key('library-sort-status'),
                minTileHeight: 44,
                minVerticalPadding: AppSpacing.md,
                leading: const Icon(Icons.tune_outlined),
                title: const Text('Status (processing first)'),
                trailing: currentMode == LibrarySortMode.status
                    ? const Icon(Icons.check)
                    : null,
                onTap: () =>
                    Navigator.of(sheetContext).pop(LibrarySortMode.status),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LibraryContent extends StatelessWidget {
  const _LibraryContent({
    required this.documents,
    required this.hasAnyDocuments,
    required this.isSearching,
    required this.searchQuery,
    required this.onSearchQueryChanged,
    required this.searchController,
    required this.onClearSearch,
    required this.onCloseSearch,
    required this.uploadState,
    required this.onUploadTap,
    required this.onUploadRetry,
    required this.onUploadReadyTap,
    required this.onDocumentTap,
    required this.onDocumentLongPress,
  });

  final List<UploadedDocument> documents;
  final bool hasAnyDocuments;
  final bool isSearching;
  final String searchQuery;
  final ValueChanged<String> onSearchQueryChanged;
  final TextEditingController searchController;
  final VoidCallback onClearSearch;
  final VoidCallback onCloseSearch;
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
    final showNoResults =
        searchQuery.trim().isNotEmpty && documents.isEmpty && hasAnyDocuments;
    final isEmpty =
        !showNoResults &&
        documents.isEmpty &&
        !showUploadCard &&
        !hasAnyDocuments;

    List<Widget> buildSearchHeader() {
      if (!isSearching) {
        return const <Widget>[];
      }

      return <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: TextField(
            key: const Key('library-search-field'),
            autofocus: true,
            onChanged: onSearchQueryChanged,
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search documents',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      key: const Key('library-clear-search'),
                      tooltip: 'Clear search',
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.clear),
                    )
                  : null,
            ),
          ),
        ),
      ];
    }

    if (isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ...buildSearchHeader(),
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
          if (isSearching)
            Center(
              child: TextButton(
                key: const Key('library-close-search'),
                onPressed: onCloseSearch,
                child: const Text('Cancel search'),
              ),
            ),
        ],
      );
    }

    final children = <Widget>[
      ...buildSearchHeader(),
      if (showUploadCard)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: DocumentUploadCard(
            state: uploadState,
            onRetry: onUploadRetry,
            onReadyTap: onUploadReadyTap,
          ),
        ),
      if (showNoResults)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Center(
            child: Column(
              children: [
                Text(
                  'No documents match your search',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tokens.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  key: const Key('library-clear-search-empty'),
                  onPressed: onClearSearch,
                  child: const Text('Clear search'),
                ),
              ],
            ),
          ),
        ),
      ...documents.map(
        (document) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Hero(
            tag: 'document-${document.id}',
            child: DocumentCard(
              document: document,
              onTap: () => onDocumentTap(document),
              onLongPress: () => onDocumentLongPress(document),
            ),
          ),
        ),
      ),
      if (isSearching)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('library-close-search'),
            onPressed: onCloseSearch,
            child: const Text('Cancel search'),
          ),
        ),
    ];

    return ListView(
      key: const Key('library-document-list'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: children,
    );
  }
}

List<UploadedDocument> _applySearchAndSort(
  List<UploadedDocument> documents,
  String query,
  LibrarySortMode sortMode,
) {
  final normalizedQuery = query.trim().toLowerCase();

  final filtered = documents
      .where(
        (document) =>
            normalizedQuery.isEmpty ||
            document.title.toLowerCase().contains(normalizedQuery),
      )
      .toList(growable: false);

  final sorted = filtered.toList(growable: false)
    ..sort((a, b) {
      switch (sortMode) {
        case LibrarySortMode.date:
          return _compareDateThenId(a, b);
        case LibrarySortMode.name:
          final nameCompare = a.title.toLowerCase().compareTo(
            b.title.toLowerCase(),
          );
          if (nameCompare != 0) {
            return nameCompare;
          }
          final dateCompare = _compareDateThenId(a, b);
          if (dateCompare != 0) {
            return dateCompare;
          }
          return a.id.compareTo(b.id);
        case LibrarySortMode.status:
          final statusCompare = _statusGroupOrder(
            a.status,
          ).compareTo(_statusGroupOrder(b.status));
          if (statusCompare != 0) {
            return statusCompare;
          }
          return _compareDateThenId(a, b);
      }
    });

  return sorted;
}

int _statusGroupOrder(String status) {
  if (status == 'ready') {
    return 1;
  }
  if (status == 'error') {
    return 2;
  }
  return 0;
}

int _compareDateThenId(UploadedDocument a, UploadedDocument b) {
  final dateCompare = b.createdAt.compareTo(a.createdAt);
  if (dateCompare != 0) {
    return dateCompare;
  }
  return a.id.compareTo(b.id);
}
