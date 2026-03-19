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

  Future<DocumentListResponse> _loadDocuments() {
    final api = ref.read(documentsApiProvider);
    return api.getDocuments(page: _defaultPage, pageSize: _defaultPageSize);
  }
}

final documentListProvider =
    AsyncNotifierProvider<DocumentListNotifier, DocumentListResponse>(
      DocumentListNotifier.new,
    );
