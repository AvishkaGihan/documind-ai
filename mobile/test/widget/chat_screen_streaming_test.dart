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
  testWidgets('chat screen renders streaming answer and citation chip', (
    WidgetTester tester,
  ) async {
    final api = _FakeChatApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
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
