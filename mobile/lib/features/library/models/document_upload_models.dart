import 'package:flutter/foundation.dart';

@immutable
class SelectedPdfFile {
  const SelectedPdfFile({
    required this.name,
    required this.sizeInBytes,
    this.path,
    this.bytes,
  });

  final String name;
  final int sizeInBytes;
  final String? path;
  final Uint8List? bytes;
}

class LibraryApiError implements Exception {
  const LibraryApiError({
    required this.code,
    required this.message,
    this.field,
  });

  final String code;
  final String message;
  final String? field;
}

class UploadedDocument {
  const UploadedDocument({
    required this.id,
    required this.title,
    required this.fileSize,
    required this.pageCount,
    required this.status,
    required this.errorMessage,
    required this.createdAt,
  });

  factory UploadedDocument.fromJson(Map<String, dynamic> json) {
    return UploadedDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      fileSize: (json['file_size'] as num).toInt(),
      pageCount: (json['page_count'] as num).toInt(),
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String title;
  final int fileSize;
  final int pageCount;
  final String status;
  final String? errorMessage;
  final DateTime createdAt;
}

enum UploadCardPhase {
  idle,
  uploading,
  processing,
  ready,
  processingError,
  failed,
}

@immutable
class DocumentUploadState {
  const DocumentUploadState({
    required this.phase,
    this.selectedFile,
    this.progress,
    this.uploadedDocument,
    this.error,
    this.announcement,
  });

  const DocumentUploadState.idle() : this(phase: UploadCardPhase.idle);

  final UploadCardPhase phase;
  final SelectedPdfFile? selectedFile;
  final double? progress;
  final UploadedDocument? uploadedDocument;
  final LibraryApiError? error;
  final String? announcement;

  DocumentUploadState copyWith({
    UploadCardPhase? phase,
    SelectedPdfFile? selectedFile,
    bool clearSelectedFile = false,
    double? progress,
    bool clearProgress = false,
    UploadedDocument? uploadedDocument,
    bool clearUploadedDocument = false,
    LibraryApiError? error,
    bool clearError = false,
    String? announcement,
    bool clearAnnouncement = false,
  }) {
    return DocumentUploadState(
      phase: phase ?? this.phase,
      selectedFile: clearSelectedFile
          ? null
          : (selectedFile ?? this.selectedFile),
      progress: clearProgress ? null : (progress ?? this.progress),
      uploadedDocument: clearUploadedDocument
          ? null
          : (uploadedDocument ?? this.uploadedDocument),
      error: clearError ? null : (error ?? this.error),
      announcement: clearAnnouncement
          ? null
          : (announcement ?? this.announcement),
    );
  }
}
