import 'package:dio/dio.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:documind_ai/features/library/providers/document_list_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('documentListProvider loads documents and refreshes', () async {
    var callCount = 0;
    final fakeApi = _FakeDocumentsApi(
      getDocumentsHandler: ({required page, required pageSize}) async {
        callCount += 1;
        return DocumentListResponse(
          items: [
            UploadedDocument(
              id: 'doc-$callCount',
              title: 'Doc $callCount',
              fileSize: 1024,
              pageCount: 1,
              status: 'ready',
              errorMessage: null,
              createdAt: DateTime.utc(2026, 3, 19),
            ),
          ],
          total: 1,
          page: page,
          pageSize: pageSize,
        );
      },
    );

    final container = ProviderContainer(
      overrides: [documentsApiProvider.overrideWithValue(fakeApi)],
    );
    addTearDown(container.dispose);

    final first = await container.read(documentListProvider.future);
    expect(callCount, 1);
    expect(first.items.first.id, 'doc-1');
    expect(first.pageSize, 100);

    await container.read(documentListProvider.notifier).refresh();

    final second = await container.read(documentListProvider.future);
    expect(callCount, 2);
    expect(second.items.first.id, 'doc-2');
  });
}

typedef _GetDocumentsHandler =
    Future<DocumentListResponse> Function({
      required int page,
      required int pageSize,
    });

class _FakeDocumentsApi extends DocumentsApi {
  _FakeDocumentsApi({required this.getDocumentsHandler}) : super(Dio());

  final _GetDocumentsHandler getDocumentsHandler;

  @override
  Future<DocumentListResponse> getDocuments({
    int page = 1,
    int pageSize = 100,
  }) async {
    return getDocumentsHandler(page: page, pageSize: pageSize);
  }
}
