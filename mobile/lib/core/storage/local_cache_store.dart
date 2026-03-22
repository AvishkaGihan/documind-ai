import 'dart:convert';
import 'dart:io' show Platform;

import 'package:documind_ai/features/auth/data/token_storage.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const int cacheSchemaVersion = 1;
const String _cacheBoxName = 'documind_cache_v1';

class QueueItemId {
  static String next() {
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return micros.toString();
  }
}

class QueuedUploadItem {
  const QueuedUploadItem({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.enqueuedAt,
    this.filePath,
    this.bytesBase64,
  });

  final String id;
  final String fileName;
  final int fileSize;
  final String? filePath;
  final String? bytesBase64;
  final DateTime enqueuedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'file_name': fileName,
      'file_size': fileSize,
      'file_path': filePath,
      'bytes_base64': bytesBase64,
      'enqueued_at': enqueuedAt.toUtc().toIso8601String(),
    };
  }

  factory QueuedUploadItem.fromJson(Map<String, dynamic> json) {
    return QueuedUploadItem(
      id: json['id'] as String,
      fileName: json['file_name'] as String,
      fileSize: (json['file_size'] as num).toInt(),
      filePath: json['file_path'] as String?,
      bytesBase64: json['bytes_base64'] as String?,
      enqueuedAt: DateTime.parse(json['enqueued_at'] as String).toUtc(),
    );
  }
}

class QueuedQuestionItem {
  const QueuedQuestionItem({
    required this.id,
    required this.documentId,
    required this.question,
    required this.enqueuedAt,
  });

  final String id;
  final String documentId;
  final String question;
  final DateTime enqueuedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'document_id': documentId,
      'question': question,
      'enqueued_at': enqueuedAt.toUtc().toIso8601String(),
    };
  }

  factory QueuedQuestionItem.fromJson(Map<String, dynamic> json) {
    return QueuedQuestionItem(
      id: json['id'] as String,
      documentId: json['document_id'] as String,
      question: json['question'] as String,
      enqueuedAt: DateTime.parse(json['enqueued_at'] as String).toUtc(),
    );
  }
}

class _CacheEnvelope {
  const _CacheEnvelope({
    required this.schemaVersion,
    required this.cachedAt,
    required this.payload,
  });

  final int schemaVersion;
  final DateTime cachedAt;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schema_version': schemaVersion,
      'cached_at': cachedAt.toUtc().toIso8601String(),
      'payload': payload,
    };
  }

  static _CacheEnvelope? fromRaw(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(raw.cast<String, dynamic>());
    final payloadRaw = map['payload'];
    if (payloadRaw is! Map) {
      return null;
    }

    final schemaVersion = (map['schema_version'] as num?)?.toInt() ?? 0;
    final cachedAtRaw = map['cached_at'] as String?;
    final cachedAt = DateTime.tryParse(cachedAtRaw ?? '')?.toUtc();
    if (schemaVersion <= 0 || cachedAt == null) {
      return null;
    }

    return _CacheEnvelope(
      schemaVersion: schemaVersion,
      cachedAt: cachedAt,
      payload: Map<String, dynamic>.from(payloadRaw.cast<String, dynamic>()),
    );
  }
}

abstract class LocalCacheStore {
  Future<void> cacheDocumentList({
    required String userNamespace,
    required DocumentListResponse response,
  });

  Future<DocumentListResponse?> readDocumentList({
    required String userNamespace,
  });

  Future<void> cacheChatMessages({
    required String userNamespace,
    required String documentId,
    required List<ChatMessage> messages,
  });

  Future<List<ChatMessage>> readChatMessages({
    required String userNamespace,
    required String documentId,
  });

  Future<void> enqueueUpload({
    required String userNamespace,
    required QueuedUploadItem item,
  });

  Future<List<QueuedUploadItem>> readQueuedUploads({
    required String userNamespace,
  });

  Future<void> removeQueuedUpload({
    required String userNamespace,
    required String queueId,
  });

  Future<void> enqueueQuestion({
    required String userNamespace,
    required QueuedQuestionItem item,
  });

  Future<List<QueuedQuestionItem>> readQueuedQuestions({
    required String userNamespace,
  });

  Future<void> removeQueuedQuestion({
    required String userNamespace,
    required String queueId,
  });
}

class HiveLocalCacheStore implements LocalCacheStore {
  HiveLocalCacheStore({this.allowHive = true});

  final bool allowHive;
  final Map<String, Object?> _fallbackMemory = <String, Object?>{};

  Future<Box<dynamic>?> _openBox() async {
    if (!allowHive) {
      return null;
    }

    try {
      if (Hive.isBoxOpen(_cacheBoxName)) {
        return Hive.box<dynamic>(_cacheBoxName);
      }
      return await Hive.openBox<dynamic>(_cacheBoxName);
    } catch (_) {
      return null;
    }
  }

  Future<void> _put(String key, Object value) async {
    final box = await _openBox();
    if (box != null) {
      await box.put(key, value);
      return;
    }
    _fallbackMemory[key] = value;
  }

  Future<Object?> _get(String key) async {
    final box = await _openBox();
    if (box != null) {
      return box.get(key);
    }
    return _fallbackMemory[key];
  }

  String _documentListKey(String namespace) => '$namespace:document_list';
  String _chatKey(String namespace, String documentId) =>
      '$namespace:chat:$documentId';
  String _queuedUploadsKey(String namespace) => '$namespace:queued_uploads';
  String _queuedQuestionsKey(String namespace) => '$namespace:queued_questions';

  @override
  Future<void> cacheDocumentList({
    required String userNamespace,
    required DocumentListResponse response,
  }) async {
    final payload = <String, dynamic>{
      'items': response.items.map(_documentToJson).toList(growable: false),
      'total': response.total,
      'page': response.page,
      'page_size': response.pageSize,
    };

    final envelope = _CacheEnvelope(
      schemaVersion: cacheSchemaVersion,
      cachedAt: DateTime.now().toUtc(),
      payload: payload,
    );

    await _put(_documentListKey(userNamespace), envelope.toJson());
  }

  @override
  Future<DocumentListResponse?> readDocumentList({
    required String userNamespace,
  }) async {
    final raw = await _get(_documentListKey(userNamespace));
    final envelope = _CacheEnvelope.fromRaw(raw);
    if (envelope == null) {
      return null;
    }

    return DocumentListResponse.fromJson(envelope.payload);
  }

  @override
  Future<void> cacheChatMessages({
    required String userNamespace,
    required String documentId,
    required List<ChatMessage> messages,
  }) async {
    final payload = <String, dynamic>{
      'items': messages.map(_chatMessageToJson).toList(growable: false),
    };

    final envelope = _CacheEnvelope(
      schemaVersion: cacheSchemaVersion,
      cachedAt: DateTime.now().toUtc(),
      payload: payload,
    );

    await _put(_chatKey(userNamespace, documentId), envelope.toJson());
  }

  @override
  Future<List<ChatMessage>> readChatMessages({
    required String userNamespace,
    required String documentId,
  }) async {
    final raw = await _get(_chatKey(userNamespace, documentId));
    final envelope = _CacheEnvelope.fromRaw(raw);
    if (envelope == null) {
      return const <ChatMessage>[];
    }

    final items = (envelope.payload['items'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item.cast<String, dynamic>()))
        .map(ChatMessage.fromJson)
        .toList(growable: false);
    return items;
  }

  @override
  Future<void> enqueueUpload({
    required String userNamespace,
    required QueuedUploadItem item,
  }) async {
    final current = await readQueuedUploads(userNamespace: userNamespace);
    final next = <Map<String, dynamic>>[
      ...current.map((queued) => queued.toJson()),
      item.toJson(),
    ];

    final envelope = _CacheEnvelope(
      schemaVersion: cacheSchemaVersion,
      cachedAt: DateTime.now().toUtc(),
      payload: <String, dynamic>{'items': next},
    );

    await _put(_queuedUploadsKey(userNamespace), envelope.toJson());
  }

  @override
  Future<List<QueuedUploadItem>> readQueuedUploads({
    required String userNamespace,
  }) async {
    final raw = await _get(_queuedUploadsKey(userNamespace));
    final envelope = _CacheEnvelope.fromRaw(raw);
    if (envelope == null) {
      return const <QueuedUploadItem>[];
    }

    final items =
        (envelope.payload['items'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item.cast<String, dynamic>()),
            )
            .map(QueuedUploadItem.fromJson)
            .toList(growable: false)
          ..sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
    return items;
  }

  @override
  Future<void> removeQueuedUpload({
    required String userNamespace,
    required String queueId,
  }) async {
    final current = await readQueuedUploads(userNamespace: userNamespace);
    final next = current
        .where((item) => item.id != queueId)
        .map((item) => item.toJson())
        .toList(growable: false);
    final envelope = _CacheEnvelope(
      schemaVersion: cacheSchemaVersion,
      cachedAt: DateTime.now().toUtc(),
      payload: <String, dynamic>{'items': next},
    );
    await _put(_queuedUploadsKey(userNamespace), envelope.toJson());
  }

  @override
  Future<void> enqueueQuestion({
    required String userNamespace,
    required QueuedQuestionItem item,
  }) async {
    final current = await readQueuedQuestions(userNamespace: userNamespace);
    final next = <Map<String, dynamic>>[
      ...current.map((queued) => queued.toJson()),
      item.toJson(),
    ];
    final envelope = _CacheEnvelope(
      schemaVersion: cacheSchemaVersion,
      cachedAt: DateTime.now().toUtc(),
      payload: <String, dynamic>{'items': next},
    );
    await _put(_queuedQuestionsKey(userNamespace), envelope.toJson());
  }

  @override
  Future<List<QueuedQuestionItem>> readQueuedQuestions({
    required String userNamespace,
  }) async {
    final raw = await _get(_queuedQuestionsKey(userNamespace));
    final envelope = _CacheEnvelope.fromRaw(raw);
    if (envelope == null) {
      return const <QueuedQuestionItem>[];
    }

    final items =
        (envelope.payload['items'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item.cast<String, dynamic>()),
            )
            .map(QueuedQuestionItem.fromJson)
            .toList(growable: false)
          ..sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
    return items;
  }

  @override
  Future<void> removeQueuedQuestion({
    required String userNamespace,
    required String queueId,
  }) async {
    final current = await readQueuedQuestions(userNamespace: userNamespace);
    final next = current
        .where((item) => item.id != queueId)
        .map((item) => item.toJson())
        .toList(growable: false);
    final envelope = _CacheEnvelope(
      schemaVersion: cacheSchemaVersion,
      cachedAt: DateTime.now().toUtc(),
      payload: <String, dynamic>{'items': next},
    );
    await _put(_queuedQuestionsKey(userNamespace), envelope.toJson());
  }

  Map<String, dynamic> _documentToJson(UploadedDocument document) {
    return <String, dynamic>{
      'id': document.id,
      'title': document.title,
      'file_size': document.fileSize,
      'page_count': document.pageCount,
      'status': document.status,
      'error_message': document.errorMessage,
      'created_at': document.createdAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _chatMessageToJson(ChatMessage message) {
    return <String, dynamic>{
      'id': message.id,
      'role': message.role == ChatRole.assistant ? 'assistant' : 'user',
      'content': message.content,
      'created_at': message.createdAt.toUtc().toIso8601String(),
      'citations': message.citations
          .map(
            (citation) => <String, dynamic>{
              'page_number': citation.pageNumber,
              'text_excerpt': citation.textExcerpt,
            },
          )
          .toList(growable: false),
    };
  }
}

String _sanitizeNamespace(String value) {
  final normalized = value.trim().toLowerCase();
  final safe = normalized.replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
  return safe.isEmpty ? 'anonymous' : safe;
}

Future<String> resolveUserCacheNamespace(Ref ref) async {
  try {
    final tokenStorage = ref.read(tokenStorageProvider);
    final session = await tokenStorage.readSession().timeout(
      const Duration(milliseconds: 10),
      onTimeout: () => null,
    );
    final userKey = session?.userId ?? session?.email ?? 'anonymous';
    return _sanitizeNamespace(userKey);
  } on MissingPluginException {
    return 'anonymous';
  } catch (_) {
    return 'anonymous';
  }
}

final localCacheStoreProvider = Provider<LocalCacheStore>((ref) {
  final isFlutterTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
  return HiveLocalCacheStore(allowHive: !isFlutterTest);
});

String? encodeBytesForQueue(List<int>? bytes) {
  if (bytes == null) {
    return null;
  }
  return base64Encode(bytes);
}

List<int>? decodeBytesFromQueue(String? bytesBase64) {
  if (bytesBase64 == null || bytesBase64.isEmpty) {
    return null;
  }
  return base64Decode(bytesBase64);
}
