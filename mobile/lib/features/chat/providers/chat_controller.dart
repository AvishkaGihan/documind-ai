import 'dart:async';
import 'dart:math';

import 'package:documind_ai/core/networking/connectivity_provider.dart';
import 'package:documind_ai/core/storage/local_cache_store.dart';
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
    this.warningMessage,
    this.errorMessage,
    this.rateLimitResetAt,
    this.lastFailedQuestion,
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
  final String? warningMessage;
  final String? errorMessage;
  final DateTime? rateLimitResetAt;
  final String? lastFailedQuestion;
  final bool isDocumentReady;

  bool get isRateLimited {
    final resetAt = rateLimitResetAt;
    if (resetAt == null) {
      return false;
    }
    return DateTime.now().toUtc().isBefore(resetAt);
  }

  int? get rateLimitRemainingSeconds {
    final resetAt = rateLimitResetAt;
    if (resetAt == null) {
      return null;
    }
    final remaining = resetAt.difference(DateTime.now().toUtc()).inSeconds;
    if (remaining <= 0) {
      return 0;
    }
    return remaining;
  }

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
    String? warningMessage,
    bool clearWarningMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? rateLimitResetAt,
    bool clearRateLimitResetAt = false,
    String? lastFailedQuestion,
    bool clearLastFailedQuestion = false,
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
      warningMessage: clearWarningMessage
          ? null
          : (warningMessage ?? this.warningMessage),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      rateLimitResetAt: clearRateLimitResetAt
          ? null
          : (rateLimitResetAt ?? this.rateLimitResetAt),
      lastFailedQuestion: clearLastFailedQuestion
          ? null
          : (lastFailedQuestion ?? this.lastFailedQuestion),
      isDocumentReady: isDocumentReady ?? this.isDocumentReady,
    );
  }
}

class ChatController extends Notifier<ChatState> {
  static const String _offlineQueuedMessage =
      'Q&A requires an internet connection. Your question will be sent when connectivity restores.';
  static const Duration _queueRetryBackoff = Duration(seconds: 15);
  static const Duration _announcementThrottle = Duration(milliseconds: 450);

  bool _isFlushingQueuedQuestions = false;
  DateTime _nextQueueFlushAt = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );
  Timer? _rateLimitTimer;
  Timer? _announcementQueueTimer;
  DateTime _nextAnnouncementAt = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );
  String _announcementBuffer = '';
  String _lastAnnouncedSentence = '';
  final List<String> _pendingAnnouncements = <String>[];

  @override
  ChatState build() {
    final connectivity = ref.read(connectivityServiceProvider);
    final sub = connectivity.onlineChanges.listen((isOnline) {
      if (!isOnline) {
        return;
      }
      final currentDocumentId = state.documentId;
      if (currentDocumentId == null) {
        return;
      }
      unawaited(_flushQueuedQuestions(currentDocumentId));
    });
    ref.onDispose(sub.cancel);
    ref.onDispose(() => _rateLimitTimer?.cancel());
    ref.onDispose(() => _announcementQueueTimer?.cancel());

    return const ChatState();
  }

  Future<void> load(String documentId) async {
    final namespace = await resolveUserCacheNamespace(ref);
    final cache = ref.read(localCacheStoreProvider);
    final isOnline = ref.read(connectivityServiceProvider).isOnline;

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
      clearWarningMessage: true,
      clearRateLimitResetAt: true,
      clearLastFailedQuestion: true,
      clearAnnouncement: true,
    );
    _resetStreamingAnnouncementState();

    if (!isOnline) {
      final cachedMessages = await cache.readChatMessages(
        userNamespace: namespace,
        documentId: documentId,
      );
      state = state.copyWith(
        documentId: documentId,
        messages: cachedMessages,
        isLoading: false,
        isDocumentReady: true,
        clearErrorMessage: true,
      );
      return;
    }

    final api = ref.read(chatApiProvider);
    try {
      final bootstrap = await api.bootstrap(documentId);
      await cache.cacheChatMessages(
        userNamespace: namespace,
        documentId: documentId,
        messages: bootstrap.messages,
      );

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
      await _flushQueuedQuestions(documentId);
    } on ChatApiError catch (error) {
      if (_isNetworkStyleError(error)) {
        final cachedMessages = await cache.readChatMessages(
          userNamespace: namespace,
          documentId: documentId,
        );
        state = state.copyWith(
          documentId: documentId,
          messages: cachedMessages,
          isLoading: false,
          isDocumentReady: true,
          clearErrorMessage: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.message,
          isDocumentReady: error.code != 'DOCUMENT_NOT_READY',
        );
      }
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
      clearWarningMessage: true,
      clearRateLimitResetAt: true,
      clearLastFailedQuestion: true,
      clearAnnouncement: true,
    );
    _resetStreamingAnnouncementState();

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

  void clearWarning() {
    state = state.copyWith(clearWarningMessage: true);
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

    if (_isRateLimitActive()) {
      final seconds = _remainingRateLimitSeconds();
      state = state.copyWith(
        warningMessage:
            "You've reached the query limit. Please wait $seconds seconds.",
      );
      return;
    }

    final isOnline = ref.read(connectivityServiceProvider).isOnline;
    if (!isOnline) {
      await _queueOfflineQuestion(trimmed);
      return;
    }

    await _sendOnlineQuestion(trimmed);
  }

  Future<void> retryLastFailedSend() async {
    final documentId = state.documentId;
    final lastFailedQuestion = state.lastFailedQuestion;
    if (documentId == null ||
        lastFailedQuestion == null ||
        state.isStreaming ||
        _isRateLimitActive()) {
      return;
    }

    await _streamAnswer(
      documentId: documentId,
      question: lastFailedQuestion,
      rethrowOnError: false,
    );
    await _persistMessages();
  }

  Future<void> _queueOfflineQuestion(String question) async {
    final documentId = state.documentId;
    if (documentId == null) {
      return;
    }

    final cache = ref.read(localCacheStoreProvider);
    final namespace = await resolveUserCacheNamespace(ref);
    await cache.enqueueQuestion(
      userNamespace: namespace,
      item: QueuedQuestionItem(
        id: QueueItemId.next(),
        documentId: documentId,
        question: question,
        enqueuedAt: DateTime.now().toUtc(),
      ),
    );

    final userMessage = ChatMessage(
      id: _localId('user'),
      role: ChatRole.user,
      content: question,
      citations: const <Citation>[],
      createdAt: DateTime.now().toUtc(),
    );
    final systemMessage = ChatMessage(
      id: _localId('assistant'),
      role: ChatRole.assistant,
      content: _offlineQueuedMessage,
      citations: const <Citation>[],
      createdAt: DateTime.now().toUtc(),
      isComplete: true,
    );

    state = state.copyWith(
      messages: <ChatMessage>[...state.messages, userMessage, systemMessage],
      inputDraft: '',
      clearErrorMessage: true,
      errorMessage: _offlineQueuedMessage,
      announcement: _offlineQueuedMessage,
    );
    await _persistMessages();
  }

  Future<void> _sendOnlineQuestion(String question) async {
    final documentId = state.documentId;
    if (documentId == null) {
      return;
    }

    final userMessage = ChatMessage(
      id: _localId('user'),
      role: ChatRole.user,
      content: question,
      citations: const <Citation>[],
      createdAt: DateTime.now().toUtc(),
    );

    state = state.copyWith(
      messages: <ChatMessage>[...state.messages, userMessage],
      inputDraft: '',
      clearErrorMessage: true,
      clearWarningMessage: true,
      clearLastFailedQuestion: true,
      clearAnnouncement: true,
    );

    await _streamAnswer(
      documentId: documentId,
      question: question,
      rethrowOnError: false,
    );
    await _persistMessages();
  }

  Future<void> _streamAnswer({
    required String documentId,
    required String question,
    String? queueId,
    bool rethrowOnError = true,
  }) async {
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
      messages: <ChatMessage>[...state.messages, assistantMessage],
      isStreaming: true,
      inFlightAnswerId: inFlightAssistantId,
      clearErrorMessage: true,
      clearAnnouncement: true,
    );
    _resetStreamingAnnouncementState();

    final api = ref.read(chatApiProvider);
    try {
      await for (final event in api.streamAsk(
        documentId: documentId,
        question: question,
      )) {
        switch (event.type) {
          case ChatSseEventType.token:
            final token = event.content ?? '';
            _appendToken(token);
            _bufferAnnouncementToken(token);
            break;
          case ChatSseEventType.citation:
            final citation = event.citation;
            if (citation != null) {
              _appendCitation(citation);
            }
            break;
          case ChatSseEventType.done:
            _completeInFlight(event.messageId ?? '');
            _flushRemainingAnnouncementText();
            state = state.copyWith(
              isStreaming: false,
              clearInFlightAnswerId: true,
              clearLastFailedQuestion: true,
            );
            if (queueId != null) {
              final namespace = await resolveUserCacheNamespace(ref);
              await ref
                  .read(localCacheStoreProvider)
                  .removeQueuedQuestion(
                    userNamespace: namespace,
                    queueId: queueId,
                  );
            }
            return;
          case ChatSseEventType.error:
            final message = event.errorMessage ?? 'Answer streaming failed.';
            _appendToken('\n\n$message');
            _completeInFlight('');
            _flushRemainingAnnouncementText();
            state = state.copyWith(
              isStreaming: false,
              clearInFlightAnswerId: true,
              errorMessage: message,
            );
            return;
        }
      }

      _completeInFlight('');
      _flushRemainingAnnouncementText();
      state = state.copyWith(
        isStreaming: false,
        clearInFlightAnswerId: true,
        clearLastFailedQuestion: true,
      );
    } on ChatApiError catch (error) {
      final isRateLimited = error.code.toUpperCase() == 'RATE_LIMITED';
      if (!isRateLimited) {
        _appendToken('\n\n${error.message}');
      }
      _completeInFlight('');

      if (isRateLimited) {
        _activateRateLimitCooldown(error.retryAfterSeconds);
        final waitSeconds =
            error.retryAfterSeconds ?? _remainingRateLimitSeconds();
        state = state.copyWith(
          isStreaming: false,
          clearInFlightAnswerId: true,
          warningMessage:
              "You've reached the query limit. Please wait $waitSeconds seconds.",
          clearErrorMessage: true,
          lastFailedQuestion: question,
        );
      } else {
        state = state.copyWith(
          isStreaming: false,
          clearInFlightAnswerId: true,
          errorMessage: error.message,
          lastFailedQuestion: question,
        );
      }
      _flushRemainingAnnouncementText();
      if (rethrowOnError) {
        rethrow;
      }
    }
  }

  Future<void> _flushQueuedQuestions(String documentId) async {
    if (_isFlushingQueuedQuestions || state.isStreaming) {
      return;
    }
    if (!ref.read(connectivityServiceProvider).isOnline) {
      return;
    }

    final now = DateTime.now().toUtc();
    if (now.isBefore(_nextQueueFlushAt)) {
      return;
    }

    _isFlushingQueuedQuestions = true;
    try {
      final namespace = await resolveUserCacheNamespace(ref);
      final cache = ref.read(localCacheStoreProvider);
      final allQueued = await cache.readQueuedQuestions(
        userNamespace: namespace,
      );
      final queuedForCurrentDoc =
          allQueued
              .where((item) => item.documentId == documentId)
              .toList(growable: false)
            ..sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));

      for (final queued in queuedForCurrentDoc) {
        try {
          await _streamAnswer(
            documentId: documentId,
            question: queued.question,
            queueId: queued.id,
            rethrowOnError: true,
          );
          await _persistMessages();
        } on ChatApiError {
          _nextQueueFlushAt = DateTime.now().toUtc().add(_queueRetryBackoff);
          return;
        }
      }
    } finally {
      _isFlushingQueuedQuestions = false;
    }
  }

  Future<void> _persistMessages() async {
    final documentId = state.documentId;
    if (documentId == null) {
      return;
    }
    final namespace = await resolveUserCacheNamespace(ref);
    final cache = ref.read(localCacheStoreProvider);
    await cache.cacheChatMessages(
      userNamespace: namespace,
      documentId: documentId,
      messages: state.messages,
    );
  }

  bool _isNetworkStyleError(ChatApiError error) {
    final code = error.code.toUpperCase();
    return code == 'NETWORK_ERROR' ||
        code == 'CONNECTION_ERROR' ||
        code == 'TIMEOUT';
  }

  bool _isRateLimitActive() {
    final resetAt = state.rateLimitResetAt;
    if (resetAt == null) {
      return false;
    }
    if (DateTime.now().toUtc().isAfter(resetAt)) {
      _clearRateLimitCooldown();
      return false;
    }
    return true;
  }

  int _remainingRateLimitSeconds() {
    final resetAt = state.rateLimitResetAt;
    if (resetAt == null) {
      return 60;
    }
    final remainingMs =
        resetAt.millisecondsSinceEpoch -
        DateTime.now().toUtc().millisecondsSinceEpoch;
    return max(1, (remainingMs / 1000).ceil());
  }

  void _activateRateLimitCooldown(int? retryAfterSeconds) {
    final seconds = retryAfterSeconds == null || retryAfterSeconds <= 0
        ? 60
        : retryAfterSeconds;
    final resetAt = DateTime.now().toUtc().add(Duration(seconds: seconds));
    _rateLimitTimer?.cancel();
    _rateLimitTimer = Timer(
      Duration(seconds: seconds),
      _clearRateLimitCooldown,
    );
    state = state.copyWith(rateLimitResetAt: resetAt);
  }

  void _clearRateLimitCooldown() {
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;
    state = state.copyWith(clearRateLimitResetAt: true);
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

  void _bufferAnnouncementToken(String token) {
    if (token.trim().isEmpty) {
      return;
    }

    _announcementBuffer = '$_announcementBuffer$token';
    _emitCompletedSentencesFromBuffer();
  }

  void _emitCompletedSentencesFromBuffer() {
    while (true) {
      final endIndex = _findSentenceBoundary(_announcementBuffer);
      if (endIndex < 0) {
        break;
      }

      final sentence = _announcementBuffer
          .substring(0, endIndex + 1)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      _announcementBuffer = _announcementBuffer.substring(endIndex + 1);
      _queueAnnouncement(sentence);
    }
  }

  int _findSentenceBoundary(String text) {
    for (var i = 0; i < text.length; i += 1) {
      final char = text[i];
      if (char != '.' && char != '!' && char != '?') {
        continue;
      }

      if (!_isSentenceBoundary(text, i)) {
        continue;
      }
      return i;
    }
    return -1;
  }

  bool _isSentenceBoundary(String text, int index) {
    final char = text[index];
    if (char == '.' && _isLikelyAbbreviation(text, index)) {
      return false;
    }
    if (char == '.' && _isDecimalPoint(text, index)) {
      return false;
    }
    if (char == '.' && _isEllipsis(text, index)) {
      return false;
    }

    if (index == text.length - 1) {
      return true;
    }

    final nextChar = text[index + 1];
    return nextChar.trim().isEmpty;
  }

  bool _isLikelyAbbreviation(String text, int periodIndex) {
    final sample = text.substring(0, periodIndex + 1);
    final abbreviationPattern = RegExp(
      r'\b(?:mr|mrs|ms|dr|prof|sr|jr|st|vs|etc|e\.g|i\.e|u\.s|u\.k)\.$',
      caseSensitive: false,
    );
    return abbreviationPattern.hasMatch(sample.trimRight());
  }

  bool _isDecimalPoint(String text, int periodIndex) {
    if (periodIndex <= 0 || periodIndex >= text.length - 1) {
      return false;
    }
    final before = text[periodIndex - 1];
    final after = text[periodIndex + 1];
    return int.tryParse(before) != null && int.tryParse(after) != null;
  }

  bool _isEllipsis(String text, int periodIndex) {
    final previousIsPeriod = periodIndex > 0 && text[periodIndex - 1] == '.';
    final nextIsPeriod =
        periodIndex < text.length - 1 && text[periodIndex + 1] == '.';
    return previousIsPeriod || nextIsPeriod;
  }

  void _queueAnnouncement(String sentence) {
    if (sentence.isEmpty || sentence == _lastAnnouncedSentence) {
      return;
    }

    final now = DateTime.now().toUtc();
    final canAnnounceNow =
        now.isAfter(_nextAnnouncementAt) ||
        now.isAtSameMomentAs(_nextAnnouncementAt);
    if (canAnnounceNow && _pendingAnnouncements.isEmpty) {
      _emitAnnouncement(sentence);
      return;
    }

    if (_pendingAnnouncements.isNotEmpty &&
        _pendingAnnouncements.last == sentence) {
      return;
    }
    _pendingAnnouncements.add(sentence);
    _scheduleAnnouncementDrain();
  }

  void _emitAnnouncement(String sentence) {
    _lastAnnouncedSentence = sentence;
    _nextAnnouncementAt = DateTime.now().toUtc().add(_announcementThrottle);
    state = state.copyWith(announcement: sentence);
  }

  void _scheduleAnnouncementDrain() {
    _announcementQueueTimer?.cancel();
    final now = DateTime.now().toUtc();
    final delay = now.isBefore(_nextAnnouncementAt)
        ? _nextAnnouncementAt.difference(now)
        : Duration.zero;

    _announcementQueueTimer = Timer(delay, () {
      if (_pendingAnnouncements.isEmpty) {
        return;
      }
      final nextSentence = _pendingAnnouncements.removeAt(0);
      _emitAnnouncement(nextSentence);
      if (_pendingAnnouncements.isNotEmpty) {
        _scheduleAnnouncementDrain();
      }
    });
  }

  void _flushRemainingAnnouncementText() {
    final remainder = _announcementBuffer
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    _announcementBuffer = '';
    if (remainder.isNotEmpty) {
      _queueAnnouncement(remainder);
    }
  }

  void _resetStreamingAnnouncementState() {
    _announcementQueueTimer?.cancel();
    _announcementQueueTimer = null;
    _announcementBuffer = '';
    _pendingAnnouncements.clear();
    _lastAnnouncedSentence = '';
    _nextAnnouncementAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
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
