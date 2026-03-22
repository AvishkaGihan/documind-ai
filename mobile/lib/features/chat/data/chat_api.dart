import 'dart:async';

import 'package:dio/dio.dart';
import 'package:documind_ai/core/networking/dio_provider.dart';
import 'package:documind_ai/features/chat/data/sse_parser.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatApiError implements Exception {
  const ChatApiError({
    required this.code,
    required this.message,
    this.field,
    this.retryAfterSeconds,
  });

  final String code;
  final String message;
  final String? field;
  final int? retryAfterSeconds;
}

class ChatApi {
  const ChatApi(this._dio, this._documentsApi);

  final Dio _dio;
  final DocumentsApi _documentsApi;

  Future<DocumentChatBootstrap> bootstrap(String documentId) async {
    try {
      final document = await _documentsApi.getDocumentById(documentId);

      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/documents/$documentId/conversations/latest/messages',
      );

      final body = response.data;
      if (body == null) {
        throw const ChatApiError(
          code: 'EMPTY_RESPONSE',
          message: 'Chat bootstrap returned no data.',
        );
      }

      final messages = MessageListResponse.fromJson(body).items;
      return DocumentChatBootstrap(
        documentTitle: document.title,
        documentStatus: document.status,
        messages: messages,
      );
    } on LibraryApiError catch (error) {
      throw ChatApiError(
        code: error.code,
        message: error.message,
        field: error.field,
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Stream<ChatSseEvent> streamAsk({
    required String documentId,
    required String question,
  }) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        '/api/v1/documents/$documentId/ask',
        data: <String, dynamic>{'question': question},
        options: Options(
          responseType: ResponseType.stream,
          headers: const <String, Object>{'Accept': 'text/event-stream'},
        ),
      );

      final body = response.data;
      if (body == null) {
        throw const ChatApiError(
          code: 'EMPTY_STREAM',
          message: 'The server did not provide a streaming response.',
        );
      }

      yield* parseSseByteStream(body.stream);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> createNewConversation(String documentId) async {
    try {
      await _dio.post<void>('/api/v1/documents/$documentId/conversations/new');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<ConversationSession>> listConversations(String documentId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/documents/$documentId/conversations',
      );
      final body = response.data;
      if (body == null) {
        throw const ChatApiError(
          code: 'EMPTY_RESPONSE',
          message: 'Conversation history returned no data.',
        );
      }

      return ConversationListResponse.fromJson(body).items;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> activateConversation({
    required String documentId,
    required String conversationId,
  }) async {
    try {
      await _dio.post<void>(
        '/api/v1/documents/$documentId/conversations/$conversationId/activate',
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  ChatApiError _mapError(DioException error) {
    if (error.response?.statusCode == 429) {
      final retryAfterSeconds = _parseRetryAfterSeconds(error);
      final dynamic data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is Map<String, dynamic>) {
          return ChatApiError(
            code: detail['code'] as String? ?? 'RATE_LIMITED',
            message: detail['message'] as String? ?? 'Too many requests.',
            field: detail['field'] as String?,
            retryAfterSeconds: retryAfterSeconds,
          );
        }
      }
      return ChatApiError(
        code: 'RATE_LIMITED',
        message: 'Too many requests.',
        retryAfterSeconds: retryAfterSeconds,
      );
    }

    final dynamic data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is Map<String, dynamic>) {
        return ChatApiError(
          code: detail['code'] as String? ?? 'UNKNOWN_ERROR',
          message: detail['message'] as String? ?? 'Something went wrong.',
          field: detail['field'] as String?,
        );
      }
    }

    return const ChatApiError(
      code: 'NETWORK_ERROR',
      message: 'Unable to reach the server. Please try again.',
    );
  }

  int? _parseRetryAfterSeconds(DioException error) {
    final headers = error.response?.headers;
    final retryAfterRaw = headers?.value('retry-after');
    if (retryAfterRaw != null) {
      final parsed = int.tryParse(retryAfterRaw.trim());
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    final resetRaw = headers?.value('x-ratelimit-reset');
    if (resetRaw != null) {
      final resetEpochSeconds = int.tryParse(resetRaw.trim());
      if (resetEpochSeconds != null) {
        final nowEpochSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final remaining = resetEpochSeconds - nowEpochSeconds;
        if (remaining > 0) {
          return remaining;
        }
      }
    }

    return null;
  }
}

final chatApiProvider = Provider<ChatApi>((ref) {
  final dio = ref.watch(dioProvider);
  final documentsApi = ref.watch(documentsApiProvider);
  return ChatApi(dio, documentsApi);
});
