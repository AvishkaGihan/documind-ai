import 'dart:async';
import 'dart:typed_data';

import 'package:documind_ai/core/networking/connectivity_provider.dart';
import 'package:documind_ai/core/storage/local_cache_store.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/data/file_picker_service.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:documind_ai/features/library/providers/document_list_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DocumentUploadController extends Notifier<DocumentUploadState> {
  static const Duration _queueRetryBackoff = Duration(seconds: 15);

  Timer? _pollTimer;
  bool _pollInFlight = false;
  bool _flushInProgress = false;
  DateTime _nextFlushAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  @override
  DocumentUploadState build() {
    final connectivity = ref.read(connectivityServiceProvider);
    final sub = connectivity.onlineChanges.listen((isOnline) {
      if (!isOnline) {
        return;
      }
      unawaited(flushQueuedUploads());
    });
    ref.onDispose(sub.cancel);
    ref.onDispose(_stopPolling);
    return const DocumentUploadState.idle();
  }

  Future<void> pickAndUpload() async {
    final picker = ref.read(pdfFilePickerProvider);
    final selectedFile = await picker.pickPdf();
    if (selectedFile == null) {
      return;
    }

    await uploadSelectedFile(selectedFile);
  }

  Future<void> uploadSelectedFile(SelectedPdfFile selectedFile) async {
    final isOnline = ref.read(connectivityServiceProvider).isOnline;
    if (!isOnline) {
      await _enqueueUpload(selectedFile);
      state = state.copyWith(
        phase: UploadCardPhase.queued,
        selectedFile: selectedFile,
        clearProgress: true,
        clearError: true,
        announcement: 'Queued - will upload when online.',
      );
      return;
    }

    await _uploadOnline(selectedFile);
  }

  Future<bool> _uploadOnline(SelectedPdfFile selectedFile) async {
    _stopPolling();
    final api = ref.read(documentsApiProvider);
    state = state.copyWith(
      phase: UploadCardPhase.uploading,
      selectedFile: selectedFile,
      progress: 0,
      clearError: true,
      clearUploadedDocument: true,
      announcement: 'Uploading ${selectedFile.name}.',
    );

    try {
      final uploaded = await api.uploadDocument(
        file: selectedFile,
        onProgress: (sent, total) {
          if (total <= 0) {
            return;
          }
          final percentage = (sent / total * 100).clamp(0, 100).toDouble();
          state = state.copyWith(
            phase: UploadCardPhase.uploading,
            selectedFile: selectedFile,
            progress: percentage,
          );
        },
      );

      state = state.copyWith(
        phase: _phaseForStatus(uploaded.status),
        selectedFile: selectedFile,
        progress: 100,
        uploadedDocument: uploaded,
        clearError: true,
        announcement: '${uploaded.title} uploaded. Processing started.',
      );
      if (ref.mounted) {
        try {
          await ref.read(documentListProvider.notifier).refresh();
        } catch (_) {
          // Keep upload success state even if list refresh fails.
        }
      }
      _startPolling(uploaded.id);
      return true;
    } on LibraryApiError catch (error) {
      _stopPolling();
      state = state.copyWith(
        phase: UploadCardPhase.failed,
        selectedFile: selectedFile,
        clearProgress: true,
        error: error,
        announcement: 'Upload failed. ${error.message}',
      );
      return false;
    }
  }

  Future<void> flushQueuedUploads() async {
    if (_flushInProgress || state.phase == UploadCardPhase.uploading) {
      return;
    }
    if (!ref.read(connectivityServiceProvider).isOnline) {
      return;
    }

    final now = DateTime.now().toUtc();
    if (now.isBefore(_nextFlushAt)) {
      return;
    }

    _flushInProgress = true;
    try {
      final cache = ref.read(localCacheStoreProvider);
      final namespace = await resolveUserCacheNamespace(ref);
      final queued = await cache.readQueuedUploads(userNamespace: namespace);

      for (final item in queued) {
        final selectedFile = _queuedUploadToSelectedFile(item);
        if (selectedFile == null) {
          await cache.removeQueuedUpload(
            userNamespace: namespace,
            queueId: item.id,
          );
          continue;
        }

        final success = await _uploadOnline(selectedFile);
        if (success) {
          await cache.removeQueuedUpload(
            userNamespace: namespace,
            queueId: item.id,
          );
        } else {
          state = state.copyWith(
            phase: UploadCardPhase.queued,
            selectedFile: selectedFile,
            clearProgress: true,
            announcement: 'Upload still queued. Will retry when online.',
          );
          _nextFlushAt = DateTime.now().toUtc().add(_queueRetryBackoff);
          return;
        }
      }
    } finally {
      _flushInProgress = false;
    }
  }

  Future<void> retryUpload() async {
    final selectedFile = state.selectedFile;
    if (selectedFile == null) {
      return;
    }
    await uploadSelectedFile(selectedFile);
  }

  void clearAnnouncement() {
    state = state.copyWith(clearAnnouncement: true);
  }

  void _startPolling(String documentId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_pollDocumentStatus(documentId));
    });
    unawaited(_pollDocumentStatus(documentId));
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollInFlight = false;
  }

  Future<void> _enqueueUpload(SelectedPdfFile selectedFile) async {
    final cache = ref.read(localCacheStoreProvider);
    final namespace = await resolveUserCacheNamespace(ref);

    await cache.enqueueUpload(
      userNamespace: namespace,
      item: QueuedUploadItem(
        id: QueueItemId.next(),
        fileName: selectedFile.name,
        fileSize: selectedFile.sizeInBytes,
        filePath: selectedFile.path,
        bytesBase64: encodeBytesForQueue(selectedFile.bytes),
        enqueuedAt: DateTime.now().toUtc(),
      ),
    );
  }

  SelectedPdfFile? _queuedUploadToSelectedFile(QueuedUploadItem item) {
    final bytes = decodeBytesFromQueue(item.bytesBase64);
    if (item.filePath == null && bytes == null) {
      return null;
    }

    return SelectedPdfFile(
      name: item.fileName,
      sizeInBytes: item.fileSize,
      path: item.filePath,
      bytes: bytes == null ? null : Uint8List.fromList(bytes),
    );
  }

  Future<void> _pollDocumentStatus(String documentId) async {
    if (!ref.mounted) {
      return;
    }
    if (_pollInFlight) {
      return;
    }

    _pollInFlight = true;
    try {
      final api = ref.read(documentsApiProvider);
      final latest = await api.getDocumentById(documentId);
      final nextPhase = _phaseForStatus(latest.status);
      final previousStatus = state.uploadedDocument?.status;
      final statusChanged = previousStatus != latest.status;

      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(
        phase: nextPhase,
        uploadedDocument: latest,
        clearError: nextPhase != UploadCardPhase.failed,
        announcement: statusChanged
            ? _announcementForStatus(latest.status)
            : null,
      );

      if (nextPhase == UploadCardPhase.ready ||
          nextPhase == UploadCardPhase.processingError) {
        _stopPolling();
      }
    } on LibraryApiError {
      // Keep current UI state and continue polling on transient failures.
    } finally {
      _pollInFlight = false;
    }
  }

  UploadCardPhase _phaseForStatus(String status) {
    switch (status) {
      case 'ready':
        return UploadCardPhase.ready;
      case 'error':
        return UploadCardPhase.processingError;
      default:
        return UploadCardPhase.processing;
    }
  }

  String _announcementForStatus(String status) {
    switch (status) {
      case 'extracting':
        return 'Extracting text.';
      case 'chunking':
        return 'Creating knowledge chunks.';
      case 'embedding':
        return 'Building intelligence index.';
      case 'ready':
        return 'Document is ready to answer your questions.';
      case 'error':
        return 'Document processing failed.';
      default:
        return 'Document processing in progress.';
    }
  }
}

final documentUploadControllerProvider =
    NotifierProvider<DocumentUploadController, DocumentUploadState>(
      DocumentUploadController.new,
    );
