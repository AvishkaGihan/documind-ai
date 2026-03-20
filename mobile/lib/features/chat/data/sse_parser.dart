import 'dart:convert';

import 'package:documind_ai/features/chat/models/chat_models.dart';

class ChatSseParser {
  final StringBuffer _buffer = StringBuffer();

  List<ChatSseEvent> addChunk(String chunk) {
    _buffer.write(chunk);
    final full = _buffer.toString();
    final frames = full.split('\n\n');
    final hasTrailingDelimiter = full.endsWith('\n\n');

    final completedFrames = hasTrailingDelimiter
        ? frames
        : frames.sublist(0, frames.length - 1);
    final pending = hasTrailingDelimiter ? '' : frames.last;

    _buffer
      ..clear()
      ..write(pending);

    final events = <ChatSseEvent>[];
    for (final frame in completedFrames) {
      if (frame.trim().isEmpty) {
        continue;
      }

      String? eventName;
      String? dataPayload;
      for (final line in frame.split('\n')) {
        if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
          continue;
        }
        if (line.startsWith('data:')) {
          final value = line.substring(5).trim();
          dataPayload = dataPayload == null ? value : '$dataPayload\n$value';
        }
      }

      if (eventName == null || dataPayload == null) {
        continue;
      }

      final decoded = _safeJsonDecode(dataPayload);
      if (decoded is! Map<String, dynamic>) {
        continue;
      }

      final event = _mapEvent(eventName, decoded);
      if (event != null) {
        events.add(event);
      }
    }

    return events;
  }

  Map<String, dynamic>? _safeJsonDecode(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  ChatSseEvent? _mapEvent(String eventName, Map<String, dynamic> payload) {
    switch (eventName) {
      case 'token':
        return ChatSseEvent.token(payload['content'] as String? ?? '');
      case 'citation':
        return ChatSseEvent.citation(Citation.fromJson(payload));
      case 'done':
        return ChatSseEvent.done(payload['message_id'] as String? ?? '');
      case 'error':
        return ChatSseEvent.error(
          code: payload['code'] as String? ?? 'STREAM_ERROR',
          message: payload['message'] as String? ?? 'Streaming failed.',
        );
      default:
        return null;
    }
  }
}

Stream<ChatSseEvent> parseSseByteStream(Stream<List<int>> bytes) async* {
  final parser = ChatSseParser();

  await for (final chunk in bytes) {
    final decoded = utf8.decode(chunk);
    for (final event in parser.addChunk(decoded)) {
      yield event;
    }
  }
}
