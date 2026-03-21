import 'dart:async';

import 'package:documind_ai/core/networking/connectivity_provider.dart';
import 'package:documind_ai/core/storage/local_cache_store.dart';
import 'package:dio/dio.dart';
import 'package:documind_ai/core/theme/app_theme.dart';
import 'package:documind_ai/features/chat/data/chat_api.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:documind_ai/features/chat/screens/chat_screen.dart';
import 'package:documind_ai/features/auth/data/token_storage.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('chat screen renders streaming answer and citation chip', (
    WidgetTester tester,
  ) async {
    final api = _FakeChatApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatApiProvider.overrideWithValue(api),
          connectivityServiceProvider.overrideWithValue(
            _FakeConnectivityService(initialOnline: true),
          ),
          localCacheStoreProvider.overrideWithValue(_FakeLocalCacheStore()),
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme.copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          home: const ChatScreen(documentId: 'doc-5'),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(
      find.byKey(const Key('chat-input-text-field')),
      'What is inside?',
    );
    await tester.pump(const Duration(milliseconds: 40));

    await tester.tap(find.byKey(const Key('chat-send-button')));
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('What is inside?'), findsOneWidget);
    expect(find.byKey(const Key('ai-typing-indicator')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 220));

    expect(find.textContaining('Streamed answer'), findsOneWidget);
    expect(find.byKey(const Key('citation-chip-4')), findsOneWidget);

    await tester.tap(find.byKey(const Key('citation-chip-4')));
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('Quoted source excerpt'), findsOneWidget);
    expect(find.byKey(const Key('ai-typing-indicator')), findsNothing);
  });

  testWidgets('chat exposes citation semantics copy and key tooltips', (
    WidgetTester tester,
  ) async {
    final api = _FakeChatApi();
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatApiProvider.overrideWithValue(api),
          connectivityServiceProvider.overrideWithValue(
            _FakeConnectivityService(initialOnline: true),
          ),
          localCacheStoreProvider.overrideWithValue(_FakeLocalCacheStore()),
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme.copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          home: const ChatScreen(documentId: 'doc-5'),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byTooltip('New conversation'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('chat-input-text-field')),
      'What is inside?',
    );
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byKey(const Key('chat-send-button')));
    await tester.pump(const Duration(milliseconds: 220));

    final semanticsWidgets = tester.widgetList<Semantics>(
      find.byType(Semantics),
    );
    final hasCitationSemantics = semanticsWidgets.any((semantics) {
      final label = semantics.properties.label;
      return label != null &&
          label.startsWith('Page reference, page 4. Tap to view source.');
    });
    expect(hasCitationSemantics, isTrue);
    semantics.dispose();
  });

  testWidgets('chat shows offline queued message when send tapped offline', (
    WidgetTester tester,
  ) async {
    final api = _FakeChatApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatApiProvider.overrideWithValue(api),
          connectivityServiceProvider.overrideWithValue(
            _FakeConnectivityService(initialOnline: false),
          ),
          localCacheStoreProvider.overrideWithValue(_FakeLocalCacheStore()),
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme.copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          home: const ChatScreen(documentId: 'doc-5'),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 60));

    await tester.enterText(
      find.byKey(const Key('chat-input-text-field')),
      'Can I queue this?',
    );
    await tester.pump(const Duration(milliseconds: 40));

    await tester.tap(find.byKey(const Key('chat-send-button')));
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      find.textContaining('Q&A requires an internet connection'),
      findsWidgets,
    );
  });

  testWidgets('typing indicator supports reduce-motion accessibility mode', (
    WidgetTester tester,
  ) async {
    final api = _FakeChatApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatApiProvider.overrideWithValue(api),
          connectivityServiceProvider.overrideWithValue(
            _FakeConnectivityService(initialOnline: true),
          ),
          localCacheStoreProvider.overrideWithValue(_FakeLocalCacheStore()),
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme.copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: ChatScreen(documentId: 'doc-5'),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 60));
    await tester.enterText(
      find.byKey(const Key('chat-input-text-field')),
      'Need a short answer',
    );
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byKey(const Key('chat-send-button')));
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('ai-typing-indicator')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat handles 429 with warning snackbar and cooldown disable', (
    WidgetTester tester,
  ) async {
    final api = _RateLimitedChatApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatApiProvider.overrideWithValue(api),
          connectivityServiceProvider.overrideWithValue(
            _FakeConnectivityService(initialOnline: true),
          ),
          localCacheStoreProvider.overrideWithValue(_FakeLocalCacheStore()),
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme.copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          home: const ChatScreen(documentId: 'doc-5'),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 60));
    await tester.enterText(
      find.byKey(const Key('chat-input-text-field')),
      'Trigger rate limit',
    );
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byKey(const Key('chat-send-button')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text("You've reached the query limit. Please wait 2 seconds."),
      findsOneWidget,
    );

    final disabledField = tester.widget<TextField>(
      find.byKey(const Key('chat-input-text-field')),
    );
    expect(disabledField.enabled, isFalse);

    await tester.pump(const Duration(seconds: 3));

    final enabledField = tester.widget<TextField>(
      find.byKey(const Key('chat-input-text-field')),
    );
    expect(enabledField.enabled, isTrue);
  });

  testWidgets('chat layout remains stable at 200% text scaling', (
    WidgetTester tester,
  ) async {
    final api = _FakeChatApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatApiProvider.overrideWithValue(api),
          connectivityServiceProvider.overrideWithValue(
            _FakeConnectivityService(initialOnline: true),
          ),
          localCacheStoreProvider.overrideWithValue(_FakeLocalCacheStore()),
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme.copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: SizedBox(width: 320, child: ChatScreen(documentId: 'doc-5')),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('chat-input-bar')), findsOneWidget);
  });
}

class _FakeChatApi extends ChatApi {
  _FakeChatApi() : super(Dio(), DocumentsApi(Dio()));

  @override
  Future<DocumentChatBootstrap> bootstrap(String documentId) async {
    return const DocumentChatBootstrap(
      documentTitle: 'Policy Handbook',
      documentStatus: 'ready',
      messages: <ChatMessage>[],
    );
  }

  @override
  Stream<ChatSseEvent> streamAsk({
    required String documentId,
    required String question,
  }) async* {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    yield const ChatSseEvent.token('Streamed answer');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    yield const ChatSseEvent.citation(
      Citation(pageNumber: 4, textExcerpt: 'Quoted source excerpt'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    yield const ChatSseEvent.done('message-id-1');
  }
}

class _RateLimitedChatApi extends ChatApi {
  _RateLimitedChatApi() : super(Dio(), DocumentsApi(Dio()));

  @override
  Future<DocumentChatBootstrap> bootstrap(String documentId) async {
    return const DocumentChatBootstrap(
      documentTitle: 'Policy Handbook',
      documentStatus: 'ready',
      messages: <ChatMessage>[],
    );
  }

  @override
  Stream<ChatSseEvent> streamAsk({
    required String documentId,
    required String question,
  }) async* {
    throw const ChatApiError(
      code: 'RATE_LIMITED',
      message: "You've reached the query limit. Please wait 2 seconds.",
      retryAfterSeconds: 2,
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
    return const DocumentListResponse(
      items: <UploadedDocument>[],
      total: 0,
      page: 1,
      pageSize: 100,
    );
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

class _FakeTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredAuthSession?> readSession() async {
    return null;
  }

  @override
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    String? userId,
    String? email,
  }) async {}
}
