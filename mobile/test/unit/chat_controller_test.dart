import 'dart:async';

import 'package:dio/dio.dart';
import 'package:documind_ai/core/networking/connectivity_provider.dart';
import 'package:documind_ai/core/storage/local_cache_store.dart';
import 'package:documind_ai/features/chat/data/chat_api.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:documind_ai/features/chat/providers/chat_controller.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat load returns cached messages when offline', () async {
    final connectivity = _FakeConnectivityService(initialOnline: false);
    final cache = _FakeLocalCacheStore()
      ..messagesByDocument['doc-1'] = <ChatMessage>[
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          content: 'Cached question',
          citations: const <Citation>[],
          createdAt: DateTime.utc(2026, 3, 19),
        ),
      ];
    final api = _FakeChatApi();

    final container = ProviderContainer(
      overrides: [
        connectivityServiceProvider.overrideWithValue(connectivity),
        localCacheStoreProvider.overrideWithValue(cache),
        chatApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    await container.read(chatControllerProvider.notifier).load('doc-1');

    final state = container.read(chatControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.messages, hasLength(1));
    expect(state.messages.single.content, 'Cached question');
    expect(api.bootstrapCallCount, 0);
  });
}

class _FakeChatApi extends ChatApi {
  _FakeChatApi() : super(Dio(), DocumentsApi(Dio()));

  int bootstrapCallCount = 0;

  @override
  Future<DocumentChatBootstrap> bootstrap(String documentId) async {
    bootstrapCallCount += 1;
    return const DocumentChatBootstrap(
      documentTitle: 'Doc',
      documentStatus: 'ready',
      messages: <ChatMessage>[],
    );
  }
}

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService({required bool initialOnline})
    : _isOnline = initialOnline;

  final bool _isOnline;
  final _controller = StreamController<bool>.broadcast();

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onlineChanges => _controller.stream;
}

class _FakeLocalCacheStore implements LocalCacheStore {
  final Map<String, List<ChatMessage>> messagesByDocument =
      <String, List<ChatMessage>>{};

  @override
  Future<void> cacheChatMessages({
    required String userNamespace,
    required String documentId,
    required List<ChatMessage> messages,
  }) async {
    messagesByDocument[documentId] = List<ChatMessage>.from(messages);
  }

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
    return List<ChatMessage>.from(messagesByDocument[documentId] ?? const []);
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
