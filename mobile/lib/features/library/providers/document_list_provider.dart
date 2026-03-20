import 'package:documind_ai/core/networking/connectivity_provider.dart';
import 'package:documind_ai/core/storage/local_cache_store.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DocumentListNotifier extends AsyncNotifier<DocumentListResponse> {
  static const int _defaultPage = 1;
  static const int _defaultPageSize = 100;

  @override
  Future<DocumentListResponse> build() {
    return _loadDocuments();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadDocuments);
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
}

final documentListProvider =
    AsyncNotifierProvider<DocumentListNotifier, DocumentListResponse>(
      DocumentListNotifier.new,
    );
