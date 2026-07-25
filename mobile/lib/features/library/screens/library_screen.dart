import 'package:documind_ai/core/layout/responsive_breakpoints.dart';
import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:documind_ai/features/library/providers/document_list_provider.dart';
import 'package:documind_ai/features/library/providers/document_upload_controller.dart';
import 'package:documind_ai/features/library/widgets/animated_gradient_border.dart';
import 'package:documind_ai/features/library/widgets/document_card.dart';
import 'package:documind_ai/features/library/widgets/document_upload_card.dart';
import 'package:documind_ai/features/library/widgets/floating_documents_animation.dart';
import 'package:documind_ai/features/library/widgets/library_sort_sheet.dart';
import 'package:documind_ai/features/library/widgets/library_stats_row.dart';
import 'package:documind_ai/features/library/widgets/staggered_list_animation.dart';
import 'package:documind_ai/shared/widgets/accessibility_focus_ring.dart';
import 'package:documind_ai/shared/widgets/app_snackbar.dart';
import 'package:documind_ai/shared/widgets/loading_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with WidgetsBindingObserver {
  String _searchQuery = '';
  LibrarySortMode _sortMode = LibrarySortMode.date;
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  bool _isFabExtended = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(documentUploadControllerProvider.notifier).flushQueuedUploads();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final direction = _scrollController.position.userScrollDirection;
    if (direction == ScrollDirection.reverse && _isFabExtended) {
      setState(() => _isFabExtended = false);
    } else if (direction == ScrollDirection.forward && !_isFabExtended) {
      setState(() => _isFabExtended = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final widthClass = classifyScreenWidth(MediaQuery.sizeOf(context).width);
    final loadingPadding =
        widthClass.isSmallPhone ? AppSpacing.md : AppSpacing.lg;
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final uploadState = ref.watch(documentUploadControllerProvider);
    final documentsAsync = ref.watch(documentListProvider).documents;
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
        showPersistentErrorSnackBar(
          context,
          tokens,
          next.error!.message,
          onRetry: () {
            ref.read(documentUploadControllerProvider.notifier).retryUpload();
          },
        );
      }

      final justProcessingFailed =
          next.phase == UploadCardPhase.processingError &&
          previous?.phase != UploadCardPhase.processingError;
      if (justProcessingFailed) {
        showPersistentErrorSnackBar(
          context,
          tokens,
          _userFriendlyProcessingError(next.uploadedDocument?.errorMessage),
          onRetry: () {
            ref.read(documentUploadControllerProvider.notifier).retryUpload();
          },
        );
      }
    });

    ref.listen<DocumentListState>(documentListProvider, (previous, next) {
      final announcement = next.announcement;
      if (announcement == null || announcement == previous?.announcement) {
        return;
      }

      final textDirection = Directionality.of(context);
      SemanticsService.sendAnnouncement(
        View.of(context),
        announcement,
        textDirection,
      );
      ref.read(documentListProvider.notifier).clearAnnouncement();
    });

    // ── Build the gradient FAB ──
    final fab = _GradientFab(
      isExtended: _isFabExtended,
      onPressed: () {
        ref.read(documentUploadControllerProvider.notifier).pickAndUpload();
      },
      hasNoDocuments: documentsAsync.whenOrNull(
            data: (r) => r.items.isEmpty,
          ) ??
          false,
    );

    return Scaffold(
      backgroundColor: tokens.colors.surfacePrimary,
      floatingActionButton: fab,
      body: RefreshIndicator(
        onRefresh: () => ref.read(documentListProvider.notifier).refresh(),
        edgeOffset: 140, // offset for sliver app bar
        child: documentsAsync.when(
          data: (response) {
            final visibleDocuments = _applySearchAndSort(
              response.items,
              searchQuery,
              sortMode,
            );

            return _LibraryContent(
              documents: visibleDocuments,
              allDocuments: response.items,
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
              sortMode: sortMode,
              onSortPressed: () async {
                final selected = await showLibrarySortSheet(context, sortMode);
                if (selected != null && context.mounted) {
                  setState(() {
                    _sortMode = selected;
                  });
                }
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
              onDeleteDocument: (document) {
                _confirmAndDelete(context, ref, document);
              },
              onInfoDocument: (document) {
                _showInfoDialog(context, document);
              },
              scrollController: _scrollController,
            );
          },
          loading: () => CustomScrollView(
            slivers: [
              _buildSliverAppBar(tokens, theme, isLoading: true),
              SliverPadding(
                padding: EdgeInsets.all(loadingPadding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: LibraryDocumentSkeletonCard(
                        key: Key('library-loading-skeleton-card-$index'),
                      ),
                    ),
                    childCount: 3,
                  ),
                ),
              ),
            ],
          ),
          error: (error, _) => CustomScrollView(
            slivers: [
              _buildSliverAppBar(tokens, theme, isLoading: false),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.all(loadingPadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(
    DocuMindTokens tokens,
    ThemeData theme, {
    required bool isLoading,
  }) {
    return SliverAppBar(
      floating: true,
      snap: true,
      expandedHeight: 140,
      backgroundColor: tokens.colors.surfacePrimary,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.colors.accentPrimary.withValues(alpha: 0.08),
                tokens.colors.accentAiGlow.withValues(alpha: 0.04),
                tokens.colors.surfacePrimary,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        titlePadding: const EdgeInsets.only(
          left: AppSpacing.xl,
          bottom: AppSpacing.lg,
        ),
        title: Text(
          'Your Library',
          style: theme.textTheme.titleLarge?.copyWith(
            color: tokens.colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      actions: [
        Semantics(
          button: true,
          label: 'Sort documents',
          child: AccessibilityFocusRing(
            borderRadius: 22,
            child: IconButton(
              key: const Key('library-sort-button'),
              tooltip: 'Sort documents',
              onPressed: () async {
                final selected =
                    await showLibrarySortSheet(context, _sortMode);
                if (selected != null && context.mounted) {
                  setState(() {
                    _sortMode = selected;
                  });
                }
              },
              icon: const ExcludeSemantics(child: Icon(Icons.sort_rounded)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showDocumentActions(
    BuildContext context,
    WidgetRef ref,
    UploadedDocument document,
  ) async {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: tokens.colors.surfaceSecondary,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            tokens.colors.textTertiary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ListTile(
                    key: Key('document-card-menu-info-${document.id}'),
                    minVerticalPadding: AppSpacing.md,
                    minTileHeight: 44,
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('Info'),
                    onTap: () => Navigator.of(sheetContext).pop('info'),
                  ),
                  ListTile(
                    key: Key('document-card-menu-delete-${document.id}'),
                    minVerticalPadding: AppSpacing.md,
                    minTileHeight: 44,
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('Delete'),
                    onTap: () => Navigator.of(sheetContext).pop('delete'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
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

String _userFriendlyProcessingError(String? backendMessage) {
  const fallback =
      'We could not process this file. Please upload a valid PDF and try again.';
  if (backendMessage == null || backendMessage.trim().isEmpty) {
    return fallback;
  }

  final normalized = backendMessage.toLowerCase();
  if (normalized.contains('failed to extract text from pdf') ||
      normalized.contains('extract text') ||
      normalized.contains('corrupt')) {
    return "This file isn't a valid PDF. Please upload a PDF file.";
  }

  return backendMessage;
}

// ═════════════════════════════════════════════════════════════════════════════
// _LibraryContent — the main scrollable body
// ═════════════════════════════════════════════════════════════════════════════

class _LibraryContent extends StatelessWidget {
  const _LibraryContent({
    required this.documents,
    required this.allDocuments,
    required this.searchQuery,
    required this.onSearchQueryChanged,
    required this.searchController,
    required this.onClearSearch,
    required this.sortMode,
    required this.onSortPressed,
    required this.uploadState,
    required this.onUploadTap,
    required this.onUploadRetry,
    required this.onUploadReadyTap,
    required this.onDocumentTap,
    required this.onDocumentLongPress,
    required this.onDeleteDocument,
    required this.onInfoDocument,
    required this.scrollController,
  });

  final List<UploadedDocument> documents;
  final List<UploadedDocument> allDocuments;
  final String searchQuery;
  final ValueChanged<String> onSearchQueryChanged;
  final TextEditingController searchController;
  final VoidCallback onClearSearch;
  final LibrarySortMode sortMode;
  final VoidCallback onSortPressed;
  final DocumentUploadState uploadState;
  final VoidCallback onUploadTap;
  final VoidCallback onUploadRetry;
  final VoidCallback? onUploadReadyTap;
  final void Function(UploadedDocument document) onDocumentTap;
  final void Function(UploadedDocument document) onDocumentLongPress;
  final void Function(UploadedDocument document) onDeleteDocument;
  final void Function(UploadedDocument document) onInfoDocument;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final widthClass = classifyScreenWidth(MediaQuery.sizeOf(context).width);
    final showUploadCard = uploadState.phase != UploadCardPhase.idle;
    final showNoResults =
        searchQuery.trim().isNotEmpty &&
        documents.isEmpty &&
        allDocuments.isNotEmpty;
    final isEmpty =
        !showNoResults &&
        documents.isEmpty &&
        !showUploadCard &&
        allDocuments.isEmpty;

    final horizontalPadding =
        widthClass.isSmallPhone ? AppSpacing.md : AppSpacing.lg;
    final itemSpacing =
        widthClass.isSmallPhone ? AppSpacing.sm : AppSpacing.md;

    // ── Compute stats ──
    final totalCount = allDocuments.length;
    final readyCount =
        allDocuments.where((d) => d.status == 'ready').length;
    final processingCount =
        allDocuments
            .where((d) => d.status != 'ready' && d.status != 'error')
            .length;

    // ── Empty state ──
    if (isEmpty) {
      return _buildEmptyState(
        context: context,
        tokens: tokens,
        theme: theme,
        horizontalPadding: horizontalPadding,
      );
    }

    // ── Content ──
    return CustomScrollView(
      key: const Key('library-layout-list'),
      controller: scrollController,
      slivers: [
        // ── SliverAppBar ──
        _buildHeroAppBar(context, tokens, theme),

        // ── Search field ──
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.sm,
            horizontalPadding,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: StaggeredListItem(
              index: 0,
              child: _SearchField(
                controller: searchController,
                query: searchQuery,
                onChanged: onSearchQueryChanged,
                onClear: onClearSearch,
              ),
            ),
          ),
        ),

        // ── Stats row ──
        if (allDocuments.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.md,
              horizontalPadding,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: LibraryStatsRow(
                totalCount: totalCount,
                readyCount: readyCount,
                processingCount: processingCount,
              ),
            ),
          ),

        // ── Upload card ──
        if (showUploadCard)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.md,
              horizontalPadding,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: StaggeredListItem(
                index: 3,
                child: DocumentUploadCard(
                  state: uploadState,
                  onRetry: onUploadRetry,
                  onReadyTap: onUploadReadyTap,
                ),
              ),
            ),
          ),

        // ── No results ──
        if (showNoResults)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2l),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: tokens.colors.textTertiary,
                    ),
                    const SizedBox(height: AppSpacing.md),
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
          ),

        // ── Document list ──
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.md,
            horizontalPadding,
            // Extra bottom padding for FAB clearance
            80 + AppSpacing.xl,
          ),
          sliver: widthClass.isTablet
              ? _buildGrid(itemSpacing)
              : _buildList(itemSpacing),
        ),
      ],
    );
  }

  SliverAppBar _buildHeroAppBar(
    BuildContext context,
    DocuMindTokens tokens,
    ThemeData theme,
  ) {
    return SliverAppBar(
      floating: true,
      snap: true,
      expandedHeight: 140,
      backgroundColor: tokens.colors.surfacePrimary,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.colors.accentPrimary.withValues(alpha: 0.08),
                tokens.colors.accentAiGlow.withValues(alpha: 0.04),
                tokens.colors.surfacePrimary,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        titlePadding: const EdgeInsets.only(
          left: AppSpacing.xl,
          bottom: AppSpacing.lg,
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Library',
              style: theme.textTheme.titleLarge?.copyWith(
                color: tokens.colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            if (allDocuments.isNotEmpty)
              Text(
                '${allDocuments.length} document${allDocuments.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.colors.textTertiary,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
      actions: [
        Semantics(
          button: true,
          label: 'Sort documents',
          child: AccessibilityFocusRing(
            borderRadius: 22,
            child: IconButton(
              key: const Key('library-sort-button'),
              tooltip: 'Sort documents',
              onPressed: onSortPressed,
              icon: const ExcludeSemantics(child: Icon(Icons.sort_rounded)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required BuildContext context,
    required DocuMindTokens tokens,
    required ThemeData theme,
    required double horizontalPadding,
  }) {
    return CustomScrollView(
      key: const Key('library-layout-list'),
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          expandedHeight: 140,
          backgroundColor: tokens.colors.surfacePrimary,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tokens.colors.accentPrimary.withValues(alpha: 0.08),
                    tokens.colors.accentAiGlow.withValues(alpha: 0.04),
                    tokens.colors.surfacePrimary,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            titlePadding: const EdgeInsets.only(
              left: AppSpacing.xl,
              bottom: AppSpacing.lg,
            ),
            title: Text(
              'Your Library',
              style: theme.textTheme.titleLarge?.copyWith(
                color: tokens.colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              AppSpacing.x3l,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Floating documents animation ──
                const FloatingDocumentsAnimation(),

                const SizedBox(height: AppSpacing.x2l),

                // ── Heading ──
                Text(
                  'Your library awaits',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: tokens.colors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // ── Subtext ──
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    'Upload your first PDF to start asking questions and extracting insights with absolute security.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.x2l),

                // ── CTA button with animated border ──
                AnimatedGradientBorder(
                  borderRadius: 14,
                  strokeWidth: 2,
                  duration: const Duration(milliseconds: 3000),
                  child: Semantics(
                    button: true,
                    label: 'Upload PDF',
                    child: FilledButton(
                      key: const Key('library-empty-upload-cta'),
                      onPressed: onUploadTap,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x2l,
                          vertical: AppSpacing.lg,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.upload_file_rounded, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Upload PDF',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Supported formats ──
                Text(
                  'Supported formats: PDF, DOCX (Max 50MB)',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tokens.colors.textTertiary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  SliverList _buildList(double itemSpacing) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final document = documents[index];
          return StaggeredListItem(
            index: index + 4, // offset for stats/search/upload items
            child: Padding(
              padding: EdgeInsets.only(bottom: itemSpacing),
              child: _SwipeableDocumentCard(
                document: document,
                onTap: () => onDocumentTap(document),
                onLongPress: () => onDocumentLongPress(document),
                onDelete: () => onDeleteDocument(document),
                onInfo: () => onInfoDocument(document),
              ),
            ),
          );
        },
        childCount: documents.length,
      ),
    );
  }

  SliverGrid _buildGrid(double itemSpacing) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final document = documents[index];
          return StaggeredListItem(
            index: index + 4,
            child: _SwipeableDocumentCard(
              document: document,
              onTap: () => onDocumentTap(document),
              onLongPress: () => onDocumentLongPress(document),
              onDelete: () => onDeleteDocument(document),
              onInfo: () => onInfoDocument(document),
            ),
          );
        },
        childCount: documents.length,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: itemSpacing,
        mainAxisSpacing: itemSpacing,
        childAspectRatio: 1.65,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Swipeable document card — wraps DocumentCard with Dismissible
// ═════════════════════════════════════════════════════════════════════════════

class _SwipeableDocumentCard extends StatelessWidget {
  const _SwipeableDocumentCard({
    required this.document,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onInfo,
  });

  final UploadedDocument document;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return Dismissible(
      key: Key('dismissible-${document.id}'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          onDelete();
        } else if (direction == DismissDirection.startToEnd) {
          onInfo();
        }
        return false; // Don't actually remove the item
      },
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: tokens.colors.accentSecondary.withValues(alpha: 0.15),
        icon: Icons.info_outline_rounded,
        iconColor: tokens.colors.accentSecondary,
        label: 'Info',
        labelColor: tokens.colors.accentSecondary,
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        color: tokens.colors.accentError.withValues(alpha: 0.15),
        icon: Icons.delete_outline_rounded,
        iconColor: tokens.colors.accentError,
        label: 'Delete',
        labelColor: tokens.colors.accentError,
      ),
      child: Hero(
        tag: 'document-${document.id}',
        child: DocumentCard(
          document: document,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
  });

  final AlignmentGeometry alignment;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Search field
// ═════════════════════════════════════════════════════════════════════════════

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return TextField(
      key: const Key('library-search-field'),
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(
        color: tokens.colors.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: 'Search documents...',
        hintStyle: TextStyle(
          color: tokens.colors.textTertiary,
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: tokens.colors.textTertiary,
          size: 20,
        ),
        suffixIcon: query.isNotEmpty
            ? IconButton(
                key: const Key('library-clear-search'),
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: Icon(
                  Icons.clear_rounded,
                  color: tokens.colors.textTertiary,
                  size: 18,
                ),
              )
            : null,
        filled: true,
        fillColor: tokens.colors.surfaceSecondary.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: tokens.colors.borderDefault.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: tokens.colors.borderDefault.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: tokens.colors.accentPrimary.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Gradient FAB
// ═════════════════════════════════════════════════════════════════════════════

class _GradientFab extends StatefulWidget {
  const _GradientFab({
    required this.isExtended,
    required this.onPressed,
    required this.hasNoDocuments,
  });

  final bool isExtended;
  final VoidCallback onPressed;
  final bool hasNoDocuments;

  @override
  State<_GradientFab> createState() => _GradientFabState();
}

class _GradientFabState extends State<_GradientFab>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion || !widget.hasNoDocuments) {
      _pulseController?.dispose();
      _pulseController = null;
      return;
    }

    _pulseController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _GradientFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.hasNoDocuments && _pulseController != null) {
      _pulseController?.dispose();
      _pulseController = null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;
    final controller = _pulseController;

    final fab = Semantics(
      button: true,
      label: 'Upload PDF',
      child: AccessibilityFocusRing(
        borderRadius: 30,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(
              widget.isExtended ? 16 : 28,
            ),
            child: InkWell(
              key: const Key('library-upload-fab'),
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(
                widget.isExtended ? 16 : 28,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tokens.colors.accentPrimary,
                      tokens.colors.accentAiGlow,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                    widget.isExtended ? 16 : 28,
                  ),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  height: 56,
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isExtended ? 20 : 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.add_rounded,
                          color: tokens.colors.textOnAccent,
                          size: 24,
                        ),
                      ),
                      if (widget.isExtended) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Upload',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tokens.colors.textOnAccent,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (controller == null) {
      return fab;
    }

    return AnimatedBuilder(
      animation: controller,
      child: fab,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              widget.isExtended ? 16 : 28,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.colors.accentPrimary.withValues(
                  alpha: 0.2 + (t * 0.25),
                ),
                blurRadius: 12 + (t * 12),
                spreadRadius: -2 + (t * 3),
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Sorting logic
// ═════════════════════════════════════════════════════════════════════════════

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
