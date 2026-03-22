import 'dart:async';

import 'package:dio/dio.dart';
import 'package:documind_ai/core/theme/app_theme.dart';
import 'package:documind_ai/features/chat/data/chat_api.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:documind_ai/features/chat/screens/chat_screen.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('new conversation confirmation clears and reloads chat', (
    WidgetTester tester,
  ) async {
    final chatApi = _FakeChatApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatApiProvider.overrideWithValue(chatApi)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ChatScreen(documentId: 'doc-a'),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Old conversation message'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-new-conversation-button')));
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Start a new conversation?'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('chat-confirm-new-conversation-button')),
    );
    await tester.pump(const Duration(milliseconds: 140));

    expect(chatApi.createdForDocuments, ['doc-a']);
    expect(find.text('Conversation cleared.'), findsOneWidget);
    expect(find.text('Old conversation message'), findsNothing);
  });
}

class _FakeChatApi extends ChatApi {
  _FakeChatApi() : super(Dio(), DocumentsApi(Dio()));

  final List<String> createdForDocuments = <String>[];

  @override
  Future<DocumentChatBootstrap> bootstrap(String documentId) async {
    if (createdForDocuments.contains(documentId)) {
      return const DocumentChatBootstrap(
        documentTitle: 'Document A',
        documentStatus: 'ready',
        messages: <ChatMessage>[],
      );
    }

    return DocumentChatBootstrap(
      documentTitle: 'Document A',
      documentStatus: 'ready',
      messages: [
        ChatMessage(
          id: 'old-message',
          role: ChatRole.assistant,
          content: 'Old conversation message',
          citations: const <Citation>[],
          createdAt: DateTime.utc(2026, 3, 20, 9, 30),
        ),
      ],
    );
  }

  @override
  Future<void> createNewConversation(String documentId) async {
    createdForDocuments.add(documentId);
  }

  @override
  Stream<ChatSseEvent> streamAsk({
    required String documentId,
    required String question,
  }) async* {
    yield const ChatSseEvent.done('noop');
  }
}
