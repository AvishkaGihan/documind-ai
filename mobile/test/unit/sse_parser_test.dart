import 'dart:convert';

import 'package:documind_ai/features/chat/data/sse_parser.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseSseByteStream parses token citation and done events', () async {
    final chunks = <List<int>>[
      utf8.encode('event: token\ndata: {"content":"Hello"}\n\n'),
      utf8.encode('event: citation\ndata: {"page":4,"text":"excerpt"}\n\n'),
      utf8.encode('event: done\ndata: {"message_id":"msg-123"}\n\n'),
    ];

    final events = await parseSseByteStream(
      Stream<List<int>>.fromIterable(chunks),
    ).toList();

    expect(events, hasLength(3));
    expect(events[0].type, ChatSseEventType.token);
    expect(events[0].content, 'Hello');

    expect(events[1].type, ChatSseEventType.citation);
    expect(events[1].citation?.pageNumber, 4);
    expect(events[1].citation?.textExcerpt, 'excerpt');

    expect(events[2].type, ChatSseEventType.done);
    expect(events[2].messageId, 'msg-123');
  });
}
