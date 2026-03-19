import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:documind_ai/core/theme/app_theme.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/data/file_picker_service.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:documind_ai/features/library/screens/library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pdfFilePickerProvider.overrideWithValue(
            _FakePdfFilePickerService(selectedFile),
          ),
          documentsApiProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LibraryScreen(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('library-upload-fab')));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('document-upload-card')), findsOneWidget);
    expect(find.byKey(const Key('upload-progress-indicator')), findsOneWidget);

    completer.complete(
      UploadedDocument(
        id: 'doc-10',
        title: 'report',
        fileSize: 4096,
        pageCount: 2,
        status: 'processing',
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
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LibraryScreen(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('library-upload-fab')));
    await tester.pump(const Duration(milliseconds: 50));

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
    await tester.pump(const Duration(milliseconds: 100));

    expect(attempts, 2);
    expect(find.byKey(const Key('upload-processing-label')), findsOneWidget);
  });
}

typedef _UploadHandler =
    Future<UploadedDocument> Function({
      required SelectedPdfFile file,
      required void Function(int sent, int total) onProgress,
    });

class _FakeDocumentsApi extends DocumentsApi {
  _FakeDocumentsApi({required this.uploadHandler}) : super(Dio());

  final _UploadHandler uploadHandler;

  @override
  Future<UploadedDocument> uploadDocument({
    required SelectedPdfFile file,
    required void Function(int sent, int total) onProgress,
  }) async {
    return uploadHandler(file: file, onProgress: onProgress);
  }
}

class _FakePdfFilePickerService implements PdfFilePickerService {
  _FakePdfFilePickerService(this.file);

  final SelectedPdfFile? file;

  @override
  Future<SelectedPdfFile?> pickPdf() async => file;
}
