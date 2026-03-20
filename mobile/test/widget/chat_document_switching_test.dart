import 'dart:async';

import 'package:dio/dio.dart';
import 'package:documind_ai/core/theme/app_theme.dart';
import 'package:documind_ai/features/chat/data/chat_api.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:documind_ai/features/chat/screens/chat_screen.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('document selector bottom sheet shows only ready documents', (
    WidgetTester tester,
  ) async {
    final chatApi = _FakeChatApi(
      bootstrapByDocumentId: {
        'doc-a': _bootstrap(title: 'Document A', message: 'A message'),
      },
    );
    final documentsApi = _FakeDocumentsApi(
      docs: [
        UploadedDocument(
          id: 'doc-a',
          title: 'Document A',
          fileSize: 100,
          pageCount: 1,
          status: 'ready',
          errorMessage: null,
          createdAt: DateTime(2026, 3, 20, 9),
        ),
        UploadedDocument(
          id: 'doc-b',
          title: 'Document B',
          fileSize: 100,
          pageCount: 1,
          status: 'processing',
          errorMessage: null,
          createdAt: DateTime(2026, 3, 20, 9),
        ),
        UploadedDocument(
          id: 'doc-c',
          title: 'Document C',
          fileSize: 100,
          pageCount: 1,
          status: 'ready',
          errorMessage: null,
          createdAt: DateTime(2026, 3, 20, 9),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatApiProvider.overrideWithValue(chatApi),
          documentsApiProvider.overrideWithValue(documentsApi),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ChatScreen(documentId: 'doc-a'),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 80));

    await tester.tap(find.byKey(const Key('chat-document-selector-button')));
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.byKey(const Key('chat-document-selector-sheet')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chat-document-option-doc-a')), findsOneWidget);
    expect(find.byKey(const Key('chat-document-option-doc-c')), findsOneWidget);
    expect(find.byKey(const Key('chat-document-option-doc-b')), findsNothing);
  });

  testWidgets('switching ChatScreen documentId reloads title and messages', (
    WidgetTester tester,
  ) async {
    final chatApi = _FakeChatApi(
      bootstrapByDocumentId: {
        'doc-a': _bootstrap(title: 'Document A', message: 'A message'),
        'doc-c': _bootstrap(title: 'Document C', message: 'C message'),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatApiProvider.overrideWithValue(chatApi)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ChatScreen(documentId: 'doc-a'),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Document A'), findsOneWidget);
    expect(find.text('A message'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatApiProvider.overrideWithValue(chatApi)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ChatScreen(documentId: 'doc-c'),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Document C'), findsOneWidget);
    expect(find.text('C message'), findsOneWidget);
    expect(find.text('A message'), findsNothing);
  });

  testWidgets('800px width shows tablet split layout with document pane', (
    WidgetTester tester,
  ) async {
    _setScreenSize(tester, const Size(800, 1024));

    final chatApi = _FakeChatApi(
      bootstrapByDocumentId: {
        'doc-a': _bootstrap(title: 'Document A', message: 'A message'),
      },
    );
    final documentsApi = _FakeDocumentsApi(
      docs: [
        UploadedDocument(
          id: 'doc-a',
          title: 'Document A',
          fileSize: 100,
          pageCount: 1,
          status: 'ready',
          errorMessage: null,
          createdAt: DateTime(2026, 3, 20, 9),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatApiProvider.overrideWithValue(chatApi),
          documentsApiProvider.overrideWithValue(documentsApi),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ChatScreen(documentId: 'doc-a'),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const Key('chat-tablet-split-layout')), findsOneWidget);
    expect(find.byKey(const Key('chat-tablet-document-pane')), findsOneWidget);
    expect(find.byKey(const Key('chat-tablet-chat-pane')), findsOneWidget);
    expect(find.byKey(const Key('chat-tablet-document-doc-a')), findsOneWidget);
  });
}

void _setScreenSize(WidgetTester tester, Size size) {
  final view = tester.view;
  view.physicalSize = size;
  view.devicePixelRatio = 1;
  addTearDown(view.resetPhysicalSize);
  addTearDown(view.resetDevicePixelRatio);
}

DocumentChatBootstrap _bootstrap({
  required String title,
  required String message,
}) {
  return DocumentChatBootstrap(
    documentTitle: title,
    documentStatus: 'ready',
    messages: [
      ChatMessage(
        id: '$title-message-id',
        role: ChatRole.assistant,
        content: message,
        citations: const [],
        createdAt: DateTime.utc(2026, 3, 20, 9, 30),
      ),
    ],
  );
}

class _FakeChatApi extends ChatApi {
  _FakeChatApi({required this.bootstrapByDocumentId})
    : super(Dio(), DocumentsApi(Dio()));

  final Map<String, DocumentChatBootstrap> bootstrapByDocumentId;

  @override
  Future<DocumentChatBootstrap> bootstrap(String documentId) async {
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
    yield const ChatSseEvent.done('noop');
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
