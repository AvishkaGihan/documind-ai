import 'dart:async';

import 'package:dio/dio.dart';
import 'package:documind_ai/core/networking/connectivity_provider.dart';
import 'package:documind_ai/core/storage/local_cache_store.dart';
import 'package:documind_ai/features/chat/data/chat_api.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:documind_ai/features/chat/providers/chat_controller.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:documind_ai/features/library/providers/document_list_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('load("active") automatically picks the first ready document if present in documentListProvider', () async {
    final connectivity = _FakeConnectivityService(initialOnline: true);
    final cache = _FakeLocalCacheStore();
    final chatApi = _FakeChatApi(
      bootstrapByDocumentId: {
        'ready-doc-1': const DocumentChatBootstrap(
          documentTitle: 'Ready Document 1',
          documentStatus: 'ready',
          messages: <ChatMessage>[],
        ),
      },
    );
    final documentsApi = _FakeDocumentsApi(
      docs: [
        UploadedDocument(
          id: 'processing-doc',
          title: 'Processing Doc',
          fileSize: 1024,
          pageCount: 1,
          status: 'processing',
          errorMessage: null,
          createdAt: DateTime.utc(2026, 3, 20),
        ),
        UploadedDocument(
          id: 'ready-doc-1',
          title: 'Ready Document 1',
          fileSize: 2048,
          pageCount: 5,
          status: 'ready',
          errorMessage: null,
          createdAt: DateTime.utc(2026, 3, 20),
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        connectivityServiceProvider.overrideWithValue(connectivity),
        localCacheStoreProvider.overrideWithValue(cache),
        chatApiProvider.overrideWithValue(chatApi),
        documentsApiProvider.overrideWithValue(documentsApi),
      ],
    );
    addTearDown(container.dispose);

    // Initial load for document list
    await container.read(documentListProvider.notifier).refreshQuietly();

    await container.read(chatControllerProvider.notifier).load('active');

    final state = container.read(chatControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.documentId, 'ready-doc-1');
    expect(state.documentTitle, 'Ready Document 1');
    expect(state.isDocumentReady, isTrue);
    expect(state.errorMessage, isNull);
  });

  test('load("active") enters clean unselected state when no ready documents exist', () async {
    final connectivity = _FakeConnectivityService(initialOnline: true);
    final cache = _FakeLocalCacheStore();
    final chatApi = _FakeChatApi(bootstrapByDocumentId: {});
    final documentsApi = _FakeDocumentsApi(
      docs: [
        UploadedDocument(
          id: 'processing-doc',
          title: 'Processing Doc',
          fileSize: 1024,
          pageCount: 1,
          status: 'processing',
          errorMessage: null,
          createdAt: DateTime.utc(2026, 3, 20),
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        connectivityServiceProvider.overrideWithValue(connectivity),
        localCacheStoreProvider.overrideWithValue(cache),
        chatApiProvider.overrideWithValue(chatApi),
        documentsApiProvider.overrideWithValue(documentsApi),
      ],
    );
    addTearDown(container.dispose);

    await container.read(documentListProvider.notifier).refreshQuietly();

    await container.read(chatControllerProvider.notifier).load('active');

    final state = container.read(chatControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.documentId, isNull);
    expect(state.documentTitle, 'No Document Selected');
    expect(state.isDocumentReady, isFalse);
    expect(state.errorMessage, isNull);
  });

  test('load gracefully handles INVALID_REQUEST_PAYLOAD and DOCUMENT_NOT_FOUND without setting errorMessage', () async {
    final connectivity = _FakeConnectivityService(initialOnline: true);
    final cache = _FakeLocalCacheStore();
    final chatApi = _FakeChatApi(
      bootstrapByDocumentId: {},
      throwErrorCode: 'INVALID_REQUEST_PAYLOAD',
    );
    final documentsApi = _FakeDocumentsApi(docs: []);

    final container = ProviderContainer(
      overrides: [
        connectivityServiceProvider.overrideWithValue(connectivity),
        localCacheStoreProvider.overrideWithValue(cache),
        chatApiProvider.overrideWithValue(chatApi),
        documentsApiProvider.overrideWithValue(documentsApi),
      ],
    );
    addTearDown(container.dispose);

    await container.read(chatControllerProvider.notifier).load('active');

    final state = container.read(chatControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.documentId, isNull);
    expect(state.documentTitle, 'No Document Selected');
    expect(state.errorMessage, isNull);
  });
}

class _FakeChatApi extends ChatApi {
  _FakeChatApi({
    required this.bootstrapByDocumentId,
    this.throwErrorCode,
  }) : super(Dio(), DocumentsApi(Dio()));

  final Map<String, DocumentChatBootstrap> bootstrapByDocumentId;
  final String? throwErrorCode;

  @override
  Future<DocumentChatBootstrap> bootstrap(String documentId) async {
    if (throwErrorCode != null) {
      throw ChatApiError(
        code: throwErrorCode!,
        message: 'Invalid request payload or document not found.',
      );
    }
    return bootstrapByDocumentId[documentId] ??
        const DocumentChatBootstrap(
          documentTitle: 'Unknown',
          documentStatus: 'ready',
          messages: <ChatMessage>[],
        );
  }

  @override
  Stream<ChatSseEvent> streamAsk({
    required String documentId,
    required String question,
  }) async* {
    yield const ChatSseEvent.done('done');
  }
}

class _FakeDocumentsApi extends DocumentsApi {
  _FakeDocumentsApi({required this.docs}) : super(Dio());

  final List<UploadedDocument> docs;

  @override
  Future<DocumentListResponse> getDocuments({
    int page = 1,
    int pageSize = 100,
  }) async {
    return DocumentListResponse(
      items: docs,
      total: docs.length,
      page: page,
      pageSize: pageSize,
    );
  }
}

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService({required this.initialOnline});

  final bool initialOnline;

  @override
  bool get isOnline => initialOnline;

  @override
  Stream<bool> get onlineChanges => const Stream<bool>.empty();
}

class _FakeLocalCacheStore implements LocalCacheStore {
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
  }) async {}

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
    return null;
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
