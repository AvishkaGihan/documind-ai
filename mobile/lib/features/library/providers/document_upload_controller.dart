import 'dart:async';

import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/data/file_picker_service.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DocumentUploadController extends Notifier<DocumentUploadState> {
  Timer? _pollTimer;
  bool _pollInFlight = false;

  @override
  DocumentUploadState build() {
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
      _startPolling(uploaded.id);
    } on LibraryApiError catch (error) {
      _stopPolling();
      state = state.copyWith(
        phase: UploadCardPhase.failed,
        selectedFile: selectedFile,
        clearProgress: true,
        error: error,
        announcement: 'Upload failed. ${error.message}',
      );
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

  Future<void> _pollDocumentStatus(String documentId) async {
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
