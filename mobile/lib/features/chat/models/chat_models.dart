import 'package:flutter/foundation.dart';

enum ChatRole { user, assistant }

@immutable
class Citation {
  const Citation({required this.pageNumber, required this.textExcerpt});

  factory Citation.fromJson(Map<String, dynamic> json) {
    return Citation(
      pageNumber: (json['page_number'] as num? ?? json['page'] as num? ?? 0)
          .toInt(),
      textExcerpt:
          (json['text_excerpt'] as String?) ?? (json['text'] as String? ?? ''),
    );
  }

  final int pageNumber;
  final String textExcerpt;
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.citations,
    required this.createdAt,
    this.isComplete = true,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final citationItems = (json['citations'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Citation.fromJson)
        .toList(growable: false);

    final roleRaw = (json['role'] as String? ?? '').toLowerCase();
    final role = roleRaw == 'assistant' ? ChatRole.assistant : ChatRole.user;

    return ChatMessage(
      id: json['id'] as String? ?? '',
      role: role,
      content: json['content'] as String? ?? '',
      citations: citationItems,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      isComplete: true,
    );
  }

  final String id;
  final ChatRole role;
  final String content;
  final List<Citation> citations;
  final DateTime createdAt;
  final bool isComplete;

  ChatMessage copyWith({
    String? id,
    String? content,
    List<Citation>? citations,
    DateTime? createdAt,
    bool? isComplete,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role,
      content: content ?? this.content,
      citations: citations ?? this.citations,
      createdAt: createdAt ?? this.createdAt,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

@immutable
class MessageListResponse {
  const MessageListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory MessageListResponse.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    return MessageListResponse(
      items: itemsJson.map(ChatMessage.fromJson).toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
    );
  }

  final List<ChatMessage> items;
  final int total;
  final int page;
  final int pageSize;
}

@immutable
class DocumentChatBootstrap {
  const DocumentChatBootstrap({
    required this.documentTitle,
    required this.documentStatus,
    required this.messages,
  });

  final String documentTitle;
  final String documentStatus;
  final List<ChatMessage> messages;

  bool get isDocumentReady => documentStatus == 'ready';
}

enum ChatSseEventType { token, citation, done, error }

@immutable
class ChatSseEvent {
  const ChatSseEvent._({
    required this.type,
    this.content,
    this.citation,
    this.messageId,
    this.errorCode,
    this.errorMessage,
  });

  const ChatSseEvent.token(String token)
    : this._(type: ChatSseEventType.token, content: token);

  const ChatSseEvent.citation(Citation citation)
    : this._(type: ChatSseEventType.citation, citation: citation);

  const ChatSseEvent.done(String messageId)
    : this._(type: ChatSseEventType.done, messageId: messageId);

  const ChatSseEvent.error({required String code, required String message})
    : this._(
        type: ChatSseEventType.error,
        errorCode: code,
        errorMessage: message,
      );

  final ChatSseEventType type;
  final String? content;
  final Citation? citation;
  final String? messageId;
  final String? errorCode;
  final String? errorMessage;
}
