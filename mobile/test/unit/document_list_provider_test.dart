import 'package:dio/dio.dart';
import 'package:documind_ai/core/networking/connectivity_provider.dart';
import 'package:documind_ai/core/storage/local_cache_store.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:documind_ai/features/library/providers/document_list_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<DocumentListResponse> waitForDocuments(
    ProviderContainer container,
  ) async {
    for (var i = 0; i < 20; i += 1) {
      final documents = container.read(documentListProvider).documents;
      if (documents.hasValue) {
        return documents.requireValue;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError('Timed out waiting for document list');
  }

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
      overrides: [
        documentsApiProvider.overrideWithValue(fakeApi),
        localCacheStoreProvider.overrideWithValue(_FakeLocalCacheStore()),
        connectivityServiceProvider.overrideWithValue(
          _FakeConnectivityService(initialOnline: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    final first = await waitForDocuments(container);
    expect(callCount, 1);
    expect(first.items.first.id, 'doc-1');
    expect(first.pageSize, 100);

    await container.read(documentListProvider.notifier).refresh();

    final second = container.read(documentListProvider).documents.requireValue;
    expect(callCount, 2);
    expect(second.items.first.id, 'doc-2');
  });

  test('returns cached list when api fails with NETWORK_ERROR', () async {
    final cached = DocumentListResponse(
      items: [
        UploadedDocument(
          id: 'cached-doc',
          title: 'Cached Doc',
          fileSize: 777,
          pageCount: 2,
          status: 'ready',
          errorMessage: null,
          createdAt: DateTime.utc(2026, 3, 19),
        ),
      ],
      total: 1,
      page: 1,
      pageSize: 100,
    );

    final cacheStore = _FakeLocalCacheStore()..cachedList = cached;
    final fakeApi = _FakeDocumentsApi(
      getDocumentsHandler: ({required page, required pageSize}) async {
        throw const LibraryApiError(
          code: 'NETWORK_ERROR',
          message: 'Unable to reach server',
        );
      },
    );

    final container = ProviderContainer(
      overrides: [
        documentsApiProvider.overrideWithValue(fakeApi),
        localCacheStoreProvider.overrideWithValue(cacheStore),
        connectivityServiceProvider.overrideWithValue(
          _FakeConnectivityService(initialOnline: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    final response = await waitForDocuments(container);
    expect(response.items.single.id, 'cached-doc');
  });

  test('refresh announces document readiness transitions by title', () async {
    var callCount = 0;
    final fakeApi = _FakeDocumentsApi(
      getDocumentsHandler: ({required page, required pageSize}) async {
        callCount += 1;
        return DocumentListResponse(
          items: [
            UploadedDocument(
              id: 'doc-announce',
              title: 'Contract Review',
              fileSize: 2048,
              pageCount: 2,
              status: callCount == 1 ? 'embedding' : 'ready',
              errorMessage: null,
              createdAt: DateTime.utc(2026, 3, 19),
            ),
          ],
          total: 1,
          page: 1,
          pageSize: 100,
        );
      },
    );

    final container = ProviderContainer(
      overrides: [
        documentsApiProvider.overrideWithValue(fakeApi),
        localCacheStoreProvider.overrideWithValue(_FakeLocalCacheStore()),
        connectivityServiceProvider.overrideWithValue(
          _FakeConnectivityService(initialOnline: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    await waitForDocuments(container);
    await container.read(documentListProvider.notifier).refresh();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    final state = container.read(documentListProvider);
    expect(state.announcement, 'Document Contract Review is now ready');
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

class _FakeLocalCacheStore implements LocalCacheStore {
  DocumentListResponse? cachedList;

  @override
  Future<void> cacheChatMessages({
    required String userNamespace,
    required String documentId,
    required List<ChatMessage> messages,
  }) async {}

  @override
  Future<void> cacheDocumentList({
    required String userNamespace,
    required DocumentListResponse response,
  }) async {
    cachedList = response;
  }

  @override
  Future<void> enqueueQuestion({
    required String userNamespace,
    required QueuedQuestionItem item,
  }) async {}

  @override
  Future<void> enqueueUpload({
    required String userNamespace,
    required QueuedUploadItem item,
  }) async {}

  @override
  Future<List<ChatMessage>> readChatMessages({
    required String userNamespace,
    required String documentId,
  }) async {
    return const <ChatMessage>[];
  }

  @override
  Future<DocumentListResponse?> readDocumentList({
    required String userNamespace,
  }) async {
    return cachedList;
  }

  @override
  Future<List<QueuedQuestionItem>> readQueuedQuestions({
    required String userNamespace,
  }) async {
    return const <QueuedQuestionItem>[];
  }

  @override
  Future<List<QueuedUploadItem>> readQueuedUploads({
    required String userNamespace,
  }) async {
    return const <QueuedUploadItem>[];
  }

  @override
  Future<void> removeQueuedQuestion({
    required String userNamespace,
    required String queueId,
  }) async {}

  @override
  Future<void> removeQueuedUpload({
    required String userNamespace,
    required String queueId,
  }) async {}
}

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService({required this.initialOnline});

  final bool initialOnline;

  @override
  bool get isOnline => initialOnline;

  @override
  Stream<bool> get onlineChanges => const Stream<bool>.empty();
}
