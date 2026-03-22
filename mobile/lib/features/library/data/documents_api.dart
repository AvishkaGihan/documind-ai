import 'package:dio/dio.dart';
import 'package:documind_ai/core/networking/dio_provider.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DocumentsApi {
  const DocumentsApi(this._dio);

  final Dio _dio;

  Future<UploadedDocument> uploadDocument({
    required SelectedPdfFile file,
    required void Function(int sent, int total) onProgress,
  }) async {
    try {
      final multipart = await _buildMultipart(file);
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/documents/upload',
        data: FormData.fromMap({'file': multipart}),
        onSendProgress: onProgress,
      );

      final body = response.data;
      if (body == null) {
        throw const LibraryApiError(
          code: 'EMPTY_RESPONSE',
          message: 'Upload completed but server returned no data.',
        );
      }
      return UploadedDocument.fromJson(body);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<UploadedDocument> getDocumentById(String documentId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/documents/$documentId',
      );
      final body = response.data;
      if (body == null) {
        throw const LibraryApiError(
          code: 'EMPTY_RESPONSE',
          message: 'Status check completed but server returned no data.',
        );
      }

      return UploadedDocument.fromJson(body);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<DocumentListResponse> getDocuments({
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/documents',
        queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
      );

      final body = response.data;
      if (body == null) {
        throw const LibraryApiError(
          code: 'EMPTY_RESPONSE',
          message: 'Document list returned no data.',
        );
      }

      return DocumentListResponse.fromJson(body);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> deleteDocument(String documentId) async {
    try {
      await _dio.delete<void>('/api/v1/documents/$documentId');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<MultipartFile> _buildMultipart(SelectedPdfFile file) async {
    if (file.path != null) {
      return MultipartFile.fromFile(file.path!, filename: file.name);
    }
    if (file.bytes != null) {
      return MultipartFile.fromBytes(file.bytes!, filename: file.name);
    }

    throw const LibraryApiError(
      code: 'INVALID_FILE',
      message: 'Unable to read selected file.',
    );
  }

  LibraryApiError _mapError(DioException error) {
    final dynamic data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is Map<String, dynamic>) {
        return LibraryApiError(
          code: detail['code'] as String? ?? 'UNKNOWN_ERROR',
          message: detail['message'] as String? ?? 'Something went wrong.',
          field: detail['field'] as String?,
        );
      }
    }

    return const LibraryApiError(
      code: 'NETWORK_ERROR',
      message: 'Unable to reach the server. Please try again.',
    );
  }
}

final documentsApiProvider = Provider<DocumentsApi>((ref) {
  final dio = ref.watch(dioProvider);
  return DocumentsApi(dio);
});
