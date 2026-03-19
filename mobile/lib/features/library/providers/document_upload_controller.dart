import 'dart:async';

import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/data/file_picker_service.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DocumentUploadController extends Notifier<DocumentUploadState> {
  @override
  DocumentUploadState build() {
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
        phase: UploadCardPhase.processing,
        selectedFile: selectedFile,
        progress: 100,
        uploadedDocument: uploaded,
        clearError: true,
        announcement: '${uploaded.title} uploaded. Processing started.',
      );
    } on LibraryApiError catch (error) {
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
}

final documentUploadControllerProvider =
    NotifierProvider<DocumentUploadController, DocumentUploadState>(
      DocumentUploadController.new,
    );
