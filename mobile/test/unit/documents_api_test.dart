import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('getDocuments parses paginated list response', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeHttpClientAdapter(
      handler: (options) async {
        expect(options.path, '/api/v1/documents');
        expect(options.queryParameters['page'], 1);
        expect(options.queryParameters['page_size'], 100);

        return _jsonResponse(<String, Object?>{
          'items': [
            {
              'id': 'doc-1',
              'title': 'Doc One',
              'file_size': 1024,
              'page_count': 2,
              'status': 'ready',
              'error_message': null,
              'created_at': '2026-03-19T12:00:00Z',
            },
          ],
          'total': 1,
          'page': 1,
          'page_size': 100,
        });
      },
    );

    final api = DocumentsApi(dio);
    final response = await api.getDocuments(page: 1, pageSize: 100);

    expect(response.total, 1);
    expect(response.page, 1);
    expect(response.pageSize, 100);
    expect(response.items, hasLength(1));
    expect(response.items.first.id, 'doc-1');
    expect(response.items.first.title, 'Doc One');
  });

  test('deleteDocument succeeds on 204 with empty body', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeHttpClientAdapter(
      handler: (options) async {
        expect(options.method, 'DELETE');
        expect(options.path, '/api/v1/documents/doc-12');
        return ResponseBody.fromString(
          '',
          204,
          headers: {
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );

    final api = DocumentsApi(dio);
    await api.deleteDocument('doc-12');
  });

  test('deleteDocument maps backend error envelope', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeHttpClientAdapter(
      handler: (options) async {
        return ResponseBody.fromString(
          jsonEncode(<String, Object?>{
            'detail': {
              'code': 'DOCUMENT_NOT_FOUND',
              'message': 'Document not found.',
              'field': null,
            },
          }),
          404,
          headers: {
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );

    final api = DocumentsApi(dio);

    expect(
      () => api.deleteDocument('missing-id'),
      throwsA(
        isA<LibraryApiError>()
            .having((error) => error.code, 'code', 'DOCUMENT_NOT_FOUND')
            .having((error) => error.message, 'message', 'Document not found.'),
      ),
    );
  });
}

ResponseBody _jsonResponse(Map<String, Object?> payload) {
  return ResponseBody.fromString(
    jsonEncode(payload),
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({required this.handler});

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }
}
