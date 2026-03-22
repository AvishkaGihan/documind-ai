import 'dart:async';
import 'dart:typed_data';

import 'package:documind_ai/core/networking/connectivity_provider.dart';
import 'package:documind_ai/core/storage/local_cache_store.dart';
import 'package:dio/dio.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/data/file_picker_service.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:documind_ai/features/library/providers/document_list_provider.dart';
import 'package:documind_ai/features/library/providers/document_upload_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller handles start, progress, and success transition', () async {
    final selectedFile = SelectedPdfFile(
      name: 'sample.pdf',
      sizeInBytes: 2048,
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
    final fakeApi = _FakeDocumentsApi(
      uploadHandler: ({required file, required onProgress}) async {
        onProgress(10, 100);
        onProgress(100, 100);
        return UploadedDocument(
          id: 'doc-1',
          title: 'sample',
          fileSize: 2048,
          pageCount: 3,
          status: 'processing',
          errorMessage: null,
          createdAt: DateTime.utc(2026, 3, 19),
        );
      },
      getHandler: (documentId) async {
        return UploadedDocument(
          id: documentId,
          title: 'sample',
          fileSize: 2048,
          pageCount: 3,
          status: 'extracting',
          errorMessage: null,
          createdAt: DateTime.utc(2026, 3, 19),
        );
      },
    );

    final container = ProviderContainer(
      overrides: [
        pdfFilePickerProvider.overrideWithValue(
          _FakePdfFilePickerService(selectedFile),
        ),
        documentsApiProvider.overrideWithValue(fakeApi),
        connectivityServiceProvider.overrideWithValue(
          _FakeConnectivityService(initialOnline: true),
        ),
        localCacheStoreProvider.overrideWithValue(_FakeLocalCacheStore()),
        documentListProvider.overrideWith(_NoopDocumentListNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(documentUploadControllerProvider.notifier)
        .pickAndUpload();

    final state = container.read(documentUploadControllerProvider);
    expect(state.phase, UploadCardPhase.processing);
    expect(state.progress, 100);
    expect(state.uploadedDocument?.title, 'sample');
    expect(fakeApi.uploadCallCount, 1);
    expect(fakeApi.getCallCount, greaterThanOrEqualTo(1));
  });

  test('controller handles failure and retry', () async {
    final selectedFile = SelectedPdfFile(
      name: 'broken.pdf',
      sizeInBytes: 1024,
      bytes: Uint8List.fromList(<int>[7, 8, 9]),
    );

    var attempt = 0;
    final fakeApi = _FakeDocumentsApi(
      uploadHandler: ({required file, required onProgress}) async {
        attempt += 1;
        if (attempt == 1) {
          throw const LibraryApiError(
            code: 'FILE_TOO_LARGE',
            message: 'Uploaded file exceeds the 50 MB limit',
          );
        }
        onProgress(100, 100);
        return UploadedDocument(
          id: 'doc-2',
          title: 'broken',
          fileSize: 1024,
          pageCount: 1,
          status: 'processing',
          errorMessage: null,
          createdAt: DateTime.utc(2026, 3, 19),
        );
      },
      getHandler: (documentId) async {
        return UploadedDocument(
          id: documentId,
          title: 'broken',
          fileSize: 1024,
          pageCount: 1,
          status: 'chunking',
          errorMessage: null,
          createdAt: DateTime.utc(2026, 3, 19),
        );
      },
    );

    final container = ProviderContainer(
      overrides: [
        pdfFilePickerProvider.overrideWithValue(
          _FakePdfFilePickerService(selectedFile),
        ),
        documentsApiProvider.overrideWithValue(fakeApi),
        connectivityServiceProvider.overrideWithValue(
          _FakeConnectivityService(initialOnline: true),
        ),
        localCacheStoreProvider.overrideWithValue(_FakeLocalCacheStore()),
        documentListProvider.overrideWith(_NoopDocumentListNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(documentUploadControllerProvider.notifier)
        .pickAndUpload();

    final failedState = container.read(documentUploadControllerProvider);
    expect(failedState.phase, UploadCardPhase.failed);
    expect(failedState.error?.code, 'FILE_TOO_LARGE');

    await container
        .read(documentUploadControllerProvider.notifier)
        .retryUpload();

    final retriedState = container.read(documentUploadControllerProvider);
    expect(retriedState.phase, UploadCardPhase.processing);
    expect(fakeApi.uploadCallCount, 2);
  });

  test('controller stops polling when status becomes ready', () async {
    final selectedFile = SelectedPdfFile(
      name: 'ready.pdf',
      sizeInBytes: 1024,
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
    final fakeApi = _FakeDocumentsApi(
      uploadHandler: ({required file, required onProgress}) async {
        onProgress(100, 100);
        return UploadedDocument(
          id: 'doc-ready',
          title: 'ready',
          fileSize: 1024,
          pageCount: 2,
          status: 'processing',
          errorMessage: null,
          createdAt: DateTime.utc(2026, 3, 19),
        );
      },
      getHandler: (documentId) async {
        if (documentId == 'doc-ready') {
          return UploadedDocument(
            id: documentId,
            title: 'ready',
            fileSize: 1024,
            pageCount: 2,
            status: 'ready',
            errorMessage: null,
            createdAt: DateTime.utc(2026, 3, 19),
          );
        }
        throw const LibraryApiError(code: 'UNKNOWN', message: 'Unexpected id');
      },
    );

    final container = ProviderContainer(
      overrides: [
        pdfFilePickerProvider.overrideWithValue(
          _FakePdfFilePickerService(selectedFile),
        ),
        documentsApiProvider.overrideWithValue(fakeApi),
        connectivityServiceProvider.overrideWithValue(
          _FakeConnectivityService(initialOnline: true),
        ),
        localCacheStoreProvider.overrideWithValue(_FakeLocalCacheStore()),
        documentListProvider.overrideWith(_NoopDocumentListNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(documentUploadControllerProvider.notifier)
        .pickAndUpload();

    await Future<void>.delayed(const Duration(milliseconds: 80));

    final state = container.read(documentUploadControllerProvider);
    expect(state.phase, UploadCardPhase.ready);
    expect(state.uploadedDocument?.status, 'ready');
    final callsAfterReady = fakeApi.getCallCount;

    await Future<void>.delayed(const Duration(milliseconds: 3200));
    expect(fakeApi.getCallCount, callsAfterReady);
  });

  test(
    'controller avoids overlapping polls while a poll is in flight',
    () async {
      final selectedFile = SelectedPdfFile(
        name: 'slow-poll.pdf',
        sizeInBytes: 1024,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      );

      final fakeApi = _FakeDocumentsApi(
        uploadHandler: ({required file, required onProgress}) async {
          onProgress(100, 100);
          return UploadedDocument(
            id: 'doc-slow',
            title: 'slow',
            fileSize: 1024,
            pageCount: 2,
            status: 'processing',
            errorMessage: null,
            createdAt: DateTime.utc(2026, 3, 19),
          );
        },
        getHandler: (documentId) async {
          await Future<void>.delayed(const Duration(milliseconds: 3500));
          return UploadedDocument(
            id: documentId,
            title: 'slow',
            fileSize: 1024,
            pageCount: 2,
            status: 'processing',
            errorMessage: null,
            createdAt: DateTime.utc(2026, 3, 19),
          );
        },
      );

      final container = ProviderContainer(
        overrides: [
          pdfFilePickerProvider.overrideWithValue(
            _FakePdfFilePickerService(selectedFile),
          ),
          documentsApiProvider.overrideWithValue(fakeApi),
          connectivityServiceProvider.overrideWithValue(
            _FakeConnectivityService(initialOnline: true),
          ),
          localCacheStoreProvider.overrideWithValue(_FakeLocalCacheStore()),
          documentListProvider.overrideWith(_NoopDocumentListNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(documentUploadControllerProvider.notifier)
          .pickAndUpload();

      await Future<void>.delayed(const Duration(milliseconds: 3300));
      expect(fakeApi.getCallCount, 1);
    },
  );

  test('offline upload is queued and flushes when back online', () async {
    final selectedFile = SelectedPdfFile(
      name: 'offline.pdf',
      sizeInBytes: 1024,
      bytes: Uint8List.fromList(<int>[4, 5, 6]),
    );
    final connectivity = _FakeConnectivityService(initialOnline: false);
    final cache = _FakeLocalCacheStore();
    final fakeApi = _FakeDocumentsApi(
      uploadHandler: ({required file, required onProgress}) async {
        onProgress(100, 100);
        return UploadedDocument(
          id: 'doc-offline',
          title: 'offline',
          fileSize: 1024,
          pageCount: 2,
          status: 'processing',
          errorMessage: null,
          createdAt: DateTime.utc(2026, 3, 19),
        );
      },
      getHandler: (documentId) async {
        return UploadedDocument(
          id: documentId,
          title: 'offline',
          fileSize: 1024,
          pageCount: 2,
          status: 'ready',
          errorMessage: null,
          createdAt: DateTime.utc(2026, 3, 19),
        );
      },
    );

    final container = ProviderContainer(
      overrides: [
        connectivityServiceProvider.overrideWithValue(connectivity),
        localCacheStoreProvider.overrideWithValue(cache),
        documentsApiProvider.overrideWithValue(fakeApi),
        documentListProvider.overrideWith(_NoopDocumentListNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(documentUploadControllerProvider.notifier)
        .uploadSelectedFile(selectedFile);

    final queuedState = container.read(documentUploadControllerProvider);
    expect(queuedState.phase, UploadCardPhase.queued);
    expect(cache.queuedUploads, hasLength(1));
    expect(fakeApi.uploadCallCount, 0);

    connectivity.emit(true);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(fakeApi.uploadCallCount, 1);
    expect(cache.queuedUploads, isEmpty);
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
  int uploadCallCount = 0;
  int getCallCount = 0;

  @override
  Future<UploadedDocument> uploadDocument({
    required SelectedPdfFile file,
    required void Function(int sent, int total) onProgress,
  }) async {
    uploadCallCount += 1;
    return uploadHandler(file: file, onProgress: onProgress);
  }

  @override
  Future<UploadedDocument> getDocumentById(String documentId) async {
    getCallCount += 1;
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

  final _controller = StreamController<bool>.broadcast();
  bool _isOnline;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onlineChanges => _controller.stream;

  void emit(bool isOnline) {
    _isOnline = isOnline;
    _controller.add(isOnline);
  }
}

class _FakeLocalCacheStore implements LocalCacheStore {
  final List<QueuedUploadItem> queuedUploads = <QueuedUploadItem>[];

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
  }) async {
    queuedUploads.add(item);
  }

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
    return List<QueuedUploadItem>.from(queuedUploads);
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
  }) async {
    queuedUploads.removeWhere((item) => item.id == queueId);
  }
}

class _NoopDocumentListNotifier extends DocumentListNotifier {
  @override
  DocumentListState build() {
    return const DocumentListState(
      documents: AsyncValue<DocumentListResponse>.data(
        DocumentListResponse(
          items: <UploadedDocument>[],
          total: 0,
          page: 1,
          pageSize: 100,
        ),
      ),
    );
  }

  @override
  Future<void> refresh() async {}
}
