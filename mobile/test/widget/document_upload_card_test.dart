import 'package:documind_ai/core/theme/app_theme.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:documind_ai/features/library/widgets/document_upload_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('processing card shows stage text updates', (tester) async {
    final baseDoc = UploadedDocument(
      id: 'doc-22',
      title: 'Status Guide',
      fileSize: 4096,
      pageCount: 12,
      status: 'extracting',
      errorMessage: null,
      createdAt: DateTime.utc(2026, 3, 19),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: DocumentUploadCard(
            state: DocumentUploadState(
              phase: UploadCardPhase.processing,
              uploadedDocument: baseDoc,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.textContaining('Extracting text'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: DocumentUploadCard(
            state: DocumentUploadState(
              phase: UploadCardPhase.processing,
              uploadedDocument: UploadedDocument(
                id: baseDoc.id,
                title: baseDoc.title,
                fileSize: baseDoc.fileSize,
                pageCount: baseDoc.pageCount,
                status: 'embedding',
                errorMessage: null,
                createdAt: baseDoc.createdAt,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.textContaining('Building intelligence index'), findsOneWidget);
  });

  testWidgets('ready state exposes tap affordance', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: DocumentUploadCard(
            state: DocumentUploadState(
              phase: UploadCardPhase.ready,
              uploadedDocument: UploadedDocument(
                id: 'doc-ready',
                title: 'Ready Doc',
                fileSize: 2048,
                pageCount: 3,
                status: 'ready',
                errorMessage: null,
                createdAt: DateTime.utc(2026, 3, 19),
              ),
            ),
            onReadyTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('document-ready-tap-target')), findsOneWidget);
    expect(find.byKey(const Key('upload-ready-label')), findsOneWidget);

    await tester.tap(find.byKey(const Key('document-ready-tap-target')));
    await tester.pump(const Duration(milliseconds: 40));

    expect(tapped, isTrue);
  });
}
