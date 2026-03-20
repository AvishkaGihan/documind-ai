import 'dart:math';

import 'package:documind_ai/features/chat/data/chat_api.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ChatState {
  const ChatState({
    this.documentId,
    this.documentTitle = '',
    this.messages = const <ChatMessage>[],
    this.inputDraft = '',
    this.isLoading = false,
    this.isStreaming = false,
    this.inFlightAnswerId,
    this.citationExcerpts = const <int, String>{},
    this.expandedCitationPages = const <int>{},
    this.announcement,
    this.errorMessage,
    this.isDocumentReady = true,
  });

  final String? documentId;
  final String documentTitle;
  final List<ChatMessage> messages;
  final String inputDraft;
  final bool isLoading;
  final bool isStreaming;
  final String? inFlightAnswerId;
  final Map<int, String> citationExcerpts;
  final Set<int> expandedCitationPages;
  final String? announcement;
  final String? errorMessage;
  final bool isDocumentReady;

  ChatState copyWith({
    String? documentId,
    String? documentTitle,
    List<ChatMessage>? messages,
    String? inputDraft,
    bool? isLoading,
    bool? isStreaming,
    String? inFlightAnswerId,
    bool clearInFlightAnswerId = false,
    Map<int, String>? citationExcerpts,
    Set<int>? expandedCitationPages,
    String? announcement,
    bool clearAnnouncement = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isDocumentReady,
  }) {
    return ChatState(
      documentId: documentId ?? this.documentId,
      documentTitle: documentTitle ?? this.documentTitle,
      messages: messages ?? this.messages,
      inputDraft: inputDraft ?? this.inputDraft,
      isLoading: isLoading ?? this.isLoading,
      isStreaming: isStreaming ?? this.isStreaming,
      inFlightAnswerId: clearInFlightAnswerId
          ? null
          : (inFlightAnswerId ?? this.inFlightAnswerId),
      citationExcerpts: citationExcerpts ?? this.citationExcerpts,
      expandedCitationPages:
          expandedCitationPages ?? this.expandedCitationPages,
      announcement: clearAnnouncement
          ? null
          : (announcement ?? this.announcement),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      isDocumentReady: isDocumentReady ?? this.isDocumentReady,
    );
  }
}

class ChatController extends Notifier<ChatState> {
  @override
  ChatState build() {
    return const ChatState();
  }

  Future<void> load(String documentId) async {
    state = state.copyWith(
      documentId: documentId,
      messages: const <ChatMessage>[],
      inputDraft: '',
      isLoading: true,
      isStreaming: false,
      clearInFlightAnswerId: true,
      citationExcerpts: const <int, String>{},
      expandedCitationPages: const <int>{},
      clearErrorMessage: true,
      clearAnnouncement: true,
    );

    final api = ref.read(chatApiProvider);
    try {
      final bootstrap = await api.bootstrap(documentId);
      state = state.copyWith(
        documentId: documentId,
        documentTitle: bootstrap.documentTitle,
        messages: bootstrap.messages,
        isLoading: false,
        isDocumentReady: bootstrap.isDocumentReady,
        errorMessage: bootstrap.isDocumentReady
            ? null
            : 'Document is still processing. Try again when status is ready.',
      );
    } on ChatApiError catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
        isDocumentReady: error.code != 'DOCUMENT_NOT_READY',
      );
    }
  }

  Future<void> startNewConversation() async {
    final documentId = state.documentId;
    if (documentId == null || state.isLoading) {
      return;
    }

    state = state.copyWith(
      messages: const <ChatMessage>[],
      inputDraft: '',
      isStreaming: false,
      clearInFlightAnswerId: true,
      citationExcerpts: const <int, String>{},
      expandedCitationPages: const <int>{},
      clearErrorMessage: true,
      clearAnnouncement: true,
    );

    final api = ref.read(chatApiProvider);
    try {
      await api.createNewConversation(documentId);
      await load(documentId);
    } on ChatApiError catch (error) {
      await load(documentId);
      state = state.copyWith(errorMessage: error.message);
    }
  }

  Future<List<ConversationSession>> listConversationHistory() async {
    final documentId = state.documentId;
    if (documentId == null) {
      return const <ConversationSession>[];
    }

    final api = ref.read(chatApiProvider);
    return api.listConversations(documentId);
  }

  Future<void> activateConversation(String conversationId) async {
    final documentId = state.documentId;
    if (documentId == null || state.isLoading) {
      return;
    }

    final api = ref.read(chatApiProvider);
    try {
      await api.activateConversation(
        documentId: documentId,
        conversationId: conversationId,
      );
      await load(documentId);
    } on ChatApiError catch (error) {
      state = state.copyWith(errorMessage: error.message);
    }
  }

  void updateDraft(String value) {
    state = state.copyWith(inputDraft: value);
  }

  void clearAnnouncement() {
    state = state.copyWith(clearAnnouncement: true);
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }

  void toggleCitation(int pageNumber) {
    final pages = Set<int>.from(state.expandedCitationPages);
    if (pages.contains(pageNumber)) {
      pages.remove(pageNumber);
    } else {
      pages.add(pageNumber);
    }
    state = state.copyWith(expandedCitationPages: pages);
  }

  Future<void> send(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || state.isStreaming || state.documentId == null) {
      return;
    }

    final userMessage = ChatMessage(
      id: _localId('user'),
      role: ChatRole.user,
      content: trimmed,
      citations: const <Citation>[],
      createdAt: DateTime.now().toUtc(),
    );

    final inFlightAssistantId = _localId('assistant');
    final assistantMessage = ChatMessage(
      id: inFlightAssistantId,
      role: ChatRole.assistant,
      content: '',
      citations: const <Citation>[],
      createdAt: DateTime.now().toUtc(),
      isComplete: false,
    );

    state = state.copyWith(
      messages: <ChatMessage>[...state.messages, userMessage, assistantMessage],
      isStreaming: true,
      inFlightAnswerId: inFlightAssistantId,
      inputDraft: '',
      clearErrorMessage: true,
      clearAnnouncement: true,
    );

    final api = ref.read(chatApiProvider);
    var didAnnounceStart = false;

    try {
      await for (final event in api.streamAsk(
        documentId: state.documentId!,
        question: trimmed,
      )) {
        switch (event.type) {
          case ChatSseEventType.token:
            if (!didAnnounceStart) {
              didAnnounceStart = true;
              state = state.copyWith(announcement: 'Answer started');
            }
            _appendToken(event.content ?? '');
            break;
          case ChatSseEventType.citation:
            final citation = event.citation;
            if (citation != null) {
              _appendCitation(citation);
            }
            break;
          case ChatSseEventType.done:
            _completeInFlight(event.messageId ?? '');
            state = state.copyWith(
              isStreaming: false,
              clearInFlightAnswerId: true,
              announcement: 'Answer complete',
            );
            return;
          case ChatSseEventType.error:
            final message = event.errorMessage ?? 'Answer streaming failed.';
            _appendToken('\n\n$message');
            _completeInFlight('');
            state = state.copyWith(
              isStreaming: false,
              clearInFlightAnswerId: true,
              errorMessage: message,
            );
            return;
        }
      }

      _completeInFlight('');
      state = state.copyWith(isStreaming: false, clearInFlightAnswerId: true);
    } on ChatApiError catch (error) {
      _appendToken('\n\n${error.message}');
      _completeInFlight('');
      state = state.copyWith(
        isStreaming: false,
        clearInFlightAnswerId: true,
        errorMessage: error.message,
      );
    }
  }

  void _appendToken(String token) {
    final inFlightId = state.inFlightAnswerId;
    if (inFlightId == null) {
      return;
    }

    state = state.copyWith(
      messages: state.messages
          .map((message) {
            if (message.id != inFlightId) {
              return message;
            }
            return message.copyWith(content: '${message.content}$token');
          })
          .toList(growable: false),
    );
  }

  void _appendCitation(Citation citation) {
    final inFlightId = state.inFlightAnswerId;
    if (inFlightId == null || citation.pageNumber <= 0) {
      return;
    }

    state = state.copyWith(
      messages: state.messages
          .map((message) {
            if (message.id != inFlightId) {
              return message;
            }

            final alreadyAdded = message.citations.any(
              (existing) => existing.pageNumber == citation.pageNumber,
            );
            if (alreadyAdded) {
              return message;
            }

            return message.copyWith(
              citations: <Citation>[...message.citations, citation],
            );
          })
          .toList(growable: false),
      citationExcerpts: <int, String>{
        ...state.citationExcerpts,
        citation.pageNumber: citation.textExcerpt,
      },
    );
  }

  void _completeInFlight(String messageId) {
    final inFlightId = state.inFlightAnswerId;
    if (inFlightId == null) {
      return;
    }

    state = state.copyWith(
      messages: state.messages
          .map((message) {
            if (message.id != inFlightId) {
              return message;
            }
            return message.copyWith(
              id: messageId.isEmpty ? message.id : messageId,
              isComplete: true,
              createdAt: DateTime.now().toUtc(),
            );
          })
          .toList(growable: false),
    );
  }

  String _localId(String rolePrefix) {
    final millis = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(100000);
    return '$rolePrefix-$millis-$random';
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);
