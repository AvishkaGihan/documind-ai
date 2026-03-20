import 'dart:async';
import 'dart:typed_data';

import 'package:documind_ai/core/networking/connectivity_provider.dart';
import 'package:documind_ai/core/storage/local_cache_store.dart';
import 'package:dio/dio.dart';
import 'package:documind_ai/core/theme/app_theme.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/data/file_picker_service.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:documind_ai/features/library/screens/library_screen.dart';
import 'package:documind_ai/features/auth/data/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpFrames(WidgetTester tester, [int count = 6]) async {
    for (var i = 0; i < count; i += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('library screen shows uploading card after file selection', (
    WidgetTester tester,
  ) async {
    final selectedFile = SelectedPdfFile(
      name: 'report.pdf',
      sizeInBytes: 4096,
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
    final completer = Completer<UploadedDocument>();
    final api = _FakeDocumentsApi(
      uploadHandler: ({required file, required onProgress}) async {
        onProgress(20, 100);
        return completer.future;
      },
      getHandler: (documentId) async {
        return UploadedDocument(
          id: documentId,
          title: 'report',
          fileSize: 4096,
          pageCount: 2,
          status: 'extracting',
          errorMessage: null,
          createdAt: DateTime.utc(2026, 3, 19),
        );
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pdfFilePickerProvider.overrideWithValue(
            _FakePdfFilePickerService(selectedFile),
          ),
          documentsApiProvider.overrideWithValue(api),
          connectivityServiceProvider.overrideWithValue(
            _FakeConnectivityService(initialOnline: true),
          ),
          localCacheStoreProvider.overrideWithValue(_FakeLocalCacheStore()),
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LibraryScreen(),
        ),
      ),
    );

    await pumpFrames(tester);

    await tester.tap(find.byKey(const Key('library-upload-fab')));
    await pumpFrames(tester, 2);

    expect(find.byKey(const Key('document-upload-card')), findsOneWidget);
    expect(find.byKey(const Key('upload-progress-indicator')), findsOneWidget);

    completer.complete(
      UploadedDocument(
        id: 'doc-10',
        title: 'report',
        fileSize: 4096,
        pageCount: 2,
        status: 'processing',
        errorMessage: null,
        createdAt: DateTime.utc(2026, 3, 19),
      ),
    );
  });

  testWidgets('library screen shows persistent error snackbar with retry', (
    WidgetTester tester,
  ) async {
    final selectedFile = SelectedPdfFile(
      name: 'retry.pdf',
      sizeInBytes: 2048,
      bytes: Uint8List.fromList(<int>[9, 9, 9]),
    );

    var attempts = 0;
    final api = _FakeDocumentsApi(
      uploadHandler: ({required file, required onProgress}) async {
        attempts += 1;
        if (attempts == 1) {
          throw const LibraryApiError(
            code: 'NETWORK_ERROR',
            message: 'Unable to reach the server. Please try again.',
          );
        }
        onProgress(100, 100);
        return UploadedDocument(
          id: 'doc-11',
          title: 'retry',
          fileSize: 2048,
          pageCount: 1,
          status: 'processing',
          errorMessage: null,
          createdAt: DateTime.utc(2026, 3, 19),
        );
      },
      getHandler: (documentId) async {
        return UploadedDocument(
          id: documentId,
          title: 'retry',
          fileSize: 2048,
          pageCount: 1,
          status: 'chunking',
          errorMessage: null,
          createdAt: DateTime.utc(2026, 3, 19),
        );
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pdfFilePickerProvider.overrideWithValue(
            _FakePdfFilePickerService(selectedFile),
          ),
          documentsApiProvider.overrideWithValue(api),
          connectivityServiceProvider.overrideWithValue(
            _FakeConnectivityService(initialOnline: true),
          ),
          localCacheStoreProvider.overrideWithValue(_FakeLocalCacheStore()),
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LibraryScreen(),
        ),
      ),
    );

    await pumpFrames(tester);

    await tester.tap(find.byKey(const Key('library-upload-fab')));
    await pumpFrames(tester, 2);

    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Unable to reach the server. Please try again.'),
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    final retryAction = tester.widget<SnackBarAction>(
      find.byType(SnackBarAction),
    );
    retryAction.onPressed();
    await pumpFrames(tester, 4);

    expect(attempts, 2);
    expect(find.byKey(const Key('upload-processing-label')), findsOneWidget);
  });

  testWidgets('library shows queued upload indicator when offline', (
    WidgetTester tester,
  ) async {
    final selectedFile = SelectedPdfFile(
      name: 'offline-report.pdf',
      sizeInBytes: 2048,
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
    final api = _FakeDocumentsApi(
      uploadHandler: ({required file, required onProgress}) async {
        throw const LibraryApiError(
          code: 'NETWORK_ERROR',
          message: 'Should not upload while offline',
        );
      },
      getHandler: (documentId) async {
        throw const LibraryApiError(code: 'NOT_USED', message: 'not used');
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pdfFilePickerProvider.overrideWithValue(
            _FakePdfFilePickerService(selectedFile),
          ),
          documentsApiProvider.overrideWithValue(api),
          connectivityServiceProvider.overrideWithValue(
            _FakeConnectivityService(initialOnline: false),
          ),
          localCacheStoreProvider.overrideWithValue(_FakeLocalCacheStore()),
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LibraryScreen(),
        ),
      ),
    );

    await pumpFrames(tester);

    await tester.tap(find.byKey(const Key('library-upload-fab')));
    await pumpFrames(tester, 3);

    expect(find.byKey(const Key('upload-queued-label')), findsOneWidget);
    expect(
      find.textContaining('Queued - will upload when online'),
      findsOneWidget,
    );
  });
}

typedef _UploadHandler =
    Future<UploadedDocument> Function({
      required SelectedPdfFile file,
      required void Function(int sent, int total) onProgress,
    });

typedef _GetHandler = Future<UploadedDocument> Function(String documentId);

class _FakeDocumentsApi extends DocumentsApi {
  _FakeDocumentsApi({required this.uploadHandler, required this.getHandler})
    : super(Dio());

  final _UploadHandler uploadHandler;
  final _GetHandler getHandler;

  @override
  Future<UploadedDocument> uploadDocument({
    required SelectedPdfFile file,
    required void Function(int sent, int total) onProgress,
  }) async {
    return uploadHandler(file: file, onProgress: onProgress);
  }

  @override
  Future<UploadedDocument> getDocumentById(String documentId) async {
    return getHandler(documentId);
  }

  @override
  Future<DocumentListResponse> getDocuments({
    int page = 1,
    int pageSize = 100,
  }) async {
    return const DocumentListResponse(
      items: <UploadedDocument>[],
      total: 0,
      page: 1,
      pageSize: 100,
    );
  }
}

class _FakePdfFilePickerService implements PdfFilePickerService {
  _FakePdfFilePickerService(this.file);

  final SelectedPdfFile? file;

  @override
  Future<SelectedPdfFile?> pickPdf() async => file;
}

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService({required bool initialOnline})
    : _isOnline = initialOnline;

  final bool _isOnline;
  final _controller = StreamController<bool>.broadcast();

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onlineChanges => _controller.stream;
}

class _FakeLocalCacheStore implements LocalCacheStore {
  @override
  Future<void> cacheChatMessages({
    required String userNamespace,
    required String documentId,
    required List<ChatMessage> messages,
  }) async {}

  @override
  Future<void> cacheDocumentList({
    required String userNamespace,
    required DocumentListResponse response,
  }) async {}

  @override
  Future<void> enqueueQuestion({
    required String userNamespace,
    required QueuedQuestionItem item,
  }) async {}

  @override
  Future<void> enqueueUpload({
    required String userNamespace,
    required QueuedUploadItem item,
  }) async {}

  @override
  Future<List<ChatMessage>> readChatMessages({
    required String userNamespace,
    required String documentId,
  }) async {
    return const <ChatMessage>[];
  }

  @override
  Future<DocumentListResponse?> readDocumentList({
    required String userNamespace,
  }) async {
    return null;
  }

  @override
  Future<List<QueuedQuestionItem>> readQueuedQuestions({
    required String userNamespace,
  }) async {
    return const <QueuedQuestionItem>[];
  }

  @override
  Future<List<QueuedUploadItem>> readQueuedUploads({
    required String userNamespace,
  }) async {
    return const <QueuedUploadItem>[];
  }

  @override
  Future<void> removeQueuedQuestion({
    required String userNamespace,
    required String queueId,
  }) async {}

  @override
  Future<void> removeQueuedUpload({
    required String userNamespace,
    required String queueId,
  }) async {}
}

class _FakeTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredAuthSession?> readSession() async {
    return null;
  }

  @override
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    String? userId,
    String? email,
  }) async {}
}
