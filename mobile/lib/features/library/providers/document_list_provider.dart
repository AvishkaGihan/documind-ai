import 'package:documind_ai/core/networking/connectivity_provider.dart';
import 'package:documind_ai/core/storage/local_cache_store.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DocumentListState {
  const DocumentListState({
    this.documents = const AsyncValue<DocumentListResponse>.loading(),
    this.announcement,
  });

  final AsyncValue<DocumentListResponse> documents;
  final String? announcement;

  DocumentListState copyWith({
    AsyncValue<DocumentListResponse>? documents,
    String? announcement,
    bool clearAnnouncement = false,
  }) {
    return DocumentListState(
      documents: documents ?? this.documents,
      announcement: clearAnnouncement
          ? null
          : (announcement ?? this.announcement),
    );
  }
}

class DocumentListNotifier extends Notifier<DocumentListState> {
  static const int _defaultPage = 1;
  static const int _defaultPageSize = 100;
  Map<String, String> _lastStatusesByDocumentId = const <String, String>{};

  @override
  DocumentListState build() {
    Future.microtask(_loadInitial);
    return const DocumentListState();
  }

  Future<void> _loadInitial() async {
    final loaded = await AsyncValue.guard(_loadDocuments);
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(documents: loaded, clearAnnouncement: true);
    _updateStatusSnapshotFromCurrentState();
  }

  Future<void> refresh() async {
    final previousStatuses = _lastStatusesByDocumentId;
    state = state.copyWith(
      documents: const AsyncValue<DocumentListResponse>.loading(),
      clearAnnouncement: true,
    );

    final nextDocuments = await AsyncValue.guard(_loadDocuments);
    if (!ref.mounted) {
      return;
    }
    final nextStatuses = nextDocuments.maybeWhen(
      data: _indexStatuses,
      orElse: () => previousStatuses,
    );

    final announcement = _buildTransitionAnnouncement(
      previousStatuses,
      nextStatuses,
      nextDocuments,
    );

    state = state.copyWith(
      documents: nextDocuments,
      announcement: announcement,
    );
    _updateStatusSnapshotFromCurrentState();
  }

  void clearAnnouncement() {
    state = state.copyWith(clearAnnouncement: true);
  }

  Future<DocumentListResponse> _loadDocuments() async {
    final api = ref.read(documentsApiProvider);
    final cache = ref.read(localCacheStoreProvider);
    final namespace = await resolveUserCacheNamespace(ref);
    final isOnline = ref.read(connectivityServiceProvider).isOnline;

    if (!isOnline) {
      final cached = await cache.readDocumentList(userNamespace: namespace);
      if (cached != null) {
        return cached;
      }
    }

    try {
      final response = await api.getDocuments(
        page: _defaultPage,
        pageSize: _defaultPageSize,
      );
      await cache.cacheDocumentList(
        userNamespace: namespace,
        response: response,
      );
      return response;
    } on LibraryApiError catch (error) {
      if (_isNetworkStyleError(error)) {
        final cached = await cache.readDocumentList(userNamespace: namespace);
        if (cached != null) {
          return cached;
        }
      }
      rethrow;
    }
  }

  bool _isNetworkStyleError(LibraryApiError error) {
    final lowered = error.code.toUpperCase();
    return lowered == 'NETWORK_ERROR' ||
        lowered == 'CONNECTION_ERROR' ||
        lowered == 'TIMEOUT';
  }

  Map<String, String> _indexStatuses(DocumentListResponse response) {
    return <String, String>{
      for (final doc in response.items) doc.id: doc.status,
    };
  }

  String? _buildTransitionAnnouncement(
    Map<String, String> previousStatuses,
    Map<String, String> nextStatuses,
    AsyncValue<DocumentListResponse> nextDocuments,
  ) {
    return nextDocuments.maybeWhen(
      data: (response) {
        for (final document in response.items) {
          final previous = previousStatuses[document.id];
          final next = nextStatuses[document.id];
          if (previous == null || previous == next || next == null) {
            continue;
          }
          if (next == 'ready') {
            return 'Document ${document.title} is now ready';
          }
          if (next == 'error') {
            return 'Document ${document.title} processing failed';
          }
        }
        return null;
      },
      orElse: () => null,
    );
  }

  void _updateStatusSnapshotFromCurrentState() {
    state.documents.whenData((response) {
      _lastStatusesByDocumentId = _indexStatuses(response);
    });
  }
}

final documentListProvider =
    NotifierProvider<DocumentListNotifier, DocumentListState>(
      DocumentListNotifier.new,
    );
