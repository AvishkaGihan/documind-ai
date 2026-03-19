import 'package:dio/dio.dart';
import 'package:documind_ai/core/theme/app_theme.dart';
import 'package:documind_ai/features/library/data/documents_api.dart';
import 'package:documind_ai/features/library/models/document_upload_models.dart';
import 'package:documind_ai/features/library/screens/library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> pumpFrames(WidgetTester tester, [int count = 6]) async {
    for (var i = 0; i < count; i += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('shows empty state and upload CTA when API returns no items', (
    WidgetTester tester,
  ) async {
    final api = _FakeDocumentsApi(
      getDocumentsHandler: ({required page, required pageSize}) async {
        return const DocumentListResponse(
          items: <UploadedDocument>[],
          total: 0,
          page: 1,
          pageSize: 100,
        );
      },
    );

    await tester.pumpWidget(_buildApp(api));
    await pumpFrames(tester);

    expect(find.text('Upload your first PDF'), findsOneWidget);
    expect(find.byKey(const Key('library-empty-upload-cta')), findsOneWidget);
  });

  testWidgets('renders list items using builder state when documents exist', (
    WidgetTester tester,
  ) async {
    final api = _FakeDocumentsApi(
      getDocumentsHandler: ({required page, required pageSize}) async {
        return DocumentListResponse(
          items: [_doc(id: 'doc-1', title: 'Annual Report')],
          total: 1,
          page: 1,
          pageSize: 100,
        );
      },
    );

    await tester.pumpWidget(_buildApp(api));
    await pumpFrames(tester);

    expect(find.byKey(const Key('library-document-list')), findsOneWidget);
    expect(find.text('Annual Report'), findsOneWidget);
  });

  testWidgets('tapping ready document navigates to chat route', (
    WidgetTester tester,
  ) async {
    final api = _FakeDocumentsApi(
      getDocumentsHandler: ({required page, required pageSize}) async {
        return DocumentListResponse(
          items: [_doc(id: 'doc-ready', title: 'Ready Doc', status: 'ready')],
          total: 1,
          page: 1,
          pageSize: 100,
        );
      },
    );

    final router = GoRouter(
      initialLocation: '/library',
      routes: [
        GoRoute(
          path: '/library',
          builder: (context, state) => const LibraryScreen(),
        ),
        GoRoute(
          path: '/chat/:documentId',
          builder: (context, state) => Scaffold(
            body: Text('chat-${state.pathParameters['documentId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [documentsApiProvider.overrideWithValue(api)],
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    );
    await pumpFrames(tester);

    await tester.tap(find.byKey(const Key('document-card-doc-ready')));
    await pumpFrames(tester, 8);

    expect(find.text('chat-doc-ready'), findsOneWidget);
  });

  testWidgets('long-press delete calls API and refreshes list', (
    WidgetTester tester,
  ) async {
    final api = _FakeDocumentsApi(
      getDocumentsHandler: ({required page, required pageSize}) async {
        apiGetCallCount += 1;
        return DocumentListResponse(
          items: [_doc(id: 'doc-delete', title: 'Delete Me', status: 'ready')],
          total: 1,
          page: 1,
          pageSize: 100,
        );
      },
      deleteHandler: (documentId) async {
        deletedIds.add(documentId);
      },
    );

    await tester.pumpWidget(_buildApp(api));
    await pumpFrames(tester);

    await tester.longPress(find.byKey(const Key('document-card-doc-delete')));
    await pumpFrames(tester, 2);
    await tester.tap(
      find.byKey(const Key('document-card-menu-delete-doc-delete')),
    );
    await pumpFrames(tester, 2);
    await tester.tap(find.byKey(const Key('confirm-delete-document-button')));
    await pumpFrames(tester, 6);

    expect(deletedIds, <String>['doc-delete']);
    expect(apiGetCallCount, greaterThanOrEqualTo(2));
  });

  testWidgets('search icon reveals search field', (WidgetTester tester) async {
    final api = _FakeDocumentsApi(
      getDocumentsHandler: ({required page, required pageSize}) async {
        return DocumentListResponse(
          items: [_doc(id: 'doc-1', title: 'Quarterly Report')],
          total: 1,
          page: 1,
          pageSize: 100,
        );
      },
    );

    await tester.pumpWidget(_buildApp(api));
    await pumpFrames(tester);

    expect(find.byKey(const Key('library-search-field')), findsNothing);

    await tester.tap(find.byKey(const Key('library-search-button')));
    await pumpFrames(tester, 2);

    expect(find.byKey(const Key('library-search-field')), findsOneWidget);
  });

  testWidgets('typing filters in real-time and case-insensitively', (
    WidgetTester tester,
  ) async {
    final api = _FakeDocumentsApi(
      getDocumentsHandler: ({required page, required pageSize}) async {
        return DocumentListResponse(
          items: [
            _doc(id: 'doc-1', title: 'Budget Plan'),
            _doc(id: 'doc-2', title: 'Project Charter'),
          ],
          total: 2,
          page: 1,
          pageSize: 100,
        );
      },
    );

    await tester.pumpWidget(_buildApp(api));
    await pumpFrames(tester);

    await tester.tap(find.byKey(const Key('library-search-button')));
    await pumpFrames(tester, 2);
    await tester.enterText(
      find.byKey(const Key('library-search-field')),
      'BUDGET',
    );
    await pumpFrames(tester, 2);

    expect(find.text('Budget Plan'), findsOneWidget);
    expect(find.text('Project Charter'), findsNothing);
  });

  testWidgets('no-results state and clear action restore full list', (
    WidgetTester tester,
  ) async {
    final api = _FakeDocumentsApi(
      getDocumentsHandler: ({required page, required pageSize}) async {
        return DocumentListResponse(
          items: [
            _doc(id: 'doc-1', title: 'Budget Plan'),
            _doc(id: 'doc-2', title: 'Project Charter'),
          ],
          total: 2,
          page: 1,
          pageSize: 100,
        );
      },
    );

    await tester.pumpWidget(_buildApp(api));
    await pumpFrames(tester);

    await tester.tap(find.byKey(const Key('library-search-button')));
    await pumpFrames(tester, 2);
    await tester.enterText(
      find.byKey(const Key('library-search-field')),
      'nope',
    );
    await pumpFrames(tester, 2);

    expect(find.text('No documents match your search'), findsOneWidget);
    expect(find.byKey(const Key('library-clear-search-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-clear-search-empty')));
    await pumpFrames(tester, 2);

    expect(find.text('Budget Plan'), findsOneWidget);
    expect(find.text('Project Charter'), findsOneWidget);
  });

  testWidgets('sort by name produces deterministic alphabetical ordering', (
    WidgetTester tester,
  ) async {
    final api = _FakeDocumentsApi(
      getDocumentsHandler: ({required page, required pageSize}) async {
        return DocumentListResponse(
          items: [
            _doc(id: 'doc-z', title: 'zulu'),
            _doc(id: 'doc-a', title: 'Alpha'),
            _doc(id: 'doc-b', title: 'beta'),
          ],
          total: 3,
          page: 1,
          pageSize: 100,
        );
      },
    );

    await tester.pumpWidget(_buildApp(api));
    await pumpFrames(tester);

    await tester.tap(find.byKey(const Key('library-sort-button')));
    await pumpFrames(tester, 8);
    await tester.ensureVisible(find.byKey(const Key('library-sort-name')));
    await pumpFrames(tester, 1);
    await tester.tap(find.byKey(const Key('library-sort-name')));
    await pumpFrames(tester, 2);

    final alphaY = tester.getTopLeft(find.text('Alpha')).dy;
    final betaY = tester.getTopLeft(find.text('beta')).dy;
    final zuluY = tester.getTopLeft(find.text('zulu')).dy;

    expect(alphaY, lessThan(betaY));
    expect(betaY, lessThan(zuluY));
  });

  testWidgets('sort by status places processing documents first', (
    WidgetTester tester,
  ) async {
    final api = _FakeDocumentsApi(
      getDocumentsHandler: ({required page, required pageSize}) async {
        return DocumentListResponse(
          items: [
            _doc(id: 'doc-ready', title: 'Ready', status: 'ready'),
            _doc(id: 'doc-processing', title: 'Processing', status: 'queued'),
            _doc(id: 'doc-error', title: 'Error', status: 'error'),
          ],
          total: 3,
          page: 1,
          pageSize: 100,
        );
      },
    );

    await tester.pumpWidget(_buildApp(api));
    await pumpFrames(tester);

    await tester.tap(find.byKey(const Key('library-sort-button')));
    await pumpFrames(tester, 8);
    await tester.ensureVisible(find.byKey(const Key('library-sort-status')));
    await pumpFrames(tester, 1);
    await tester.tap(find.byKey(const Key('library-sort-status')));
    await pumpFrames(tester, 2);

    final processingY = tester
        .getTopLeft(find.byKey(const Key('document-card-doc-processing')))
        .dy;
    final readyY = tester
        .getTopLeft(find.byKey(const Key('document-card-doc-ready')))
        .dy;
    final errorY = tester
        .getTopLeft(find.byKey(const Key('document-card-doc-error')))
        .dy;

    expect(processingY, lessThan(readyY));
    expect(readyY, lessThan(errorY));
  });
}

int apiGetCallCount = 0;
final List<String> deletedIds = <String>[];

Widget _buildApp(_FakeDocumentsApi api) {
  return ProviderScope(
    overrides: [documentsApiProvider.overrideWithValue(api)],
    child: MaterialApp(theme: AppTheme.darkTheme, home: const LibraryScreen()),
  );
}

UploadedDocument _doc({
  required String id,
  required String title,
  String status = 'ready',
}) {
  return UploadedDocument(
    id: id,
    title: title,
    fileSize: 4096,
    pageCount: 3,
    status: status,
    errorMessage: status == 'error' ? 'Failed processing' : null,
    createdAt: DateTime.utc(2026, 3, 19, 10, 30),
  );
}

typedef _GetDocumentsHandler =
    Future<DocumentListResponse> Function({
      required int page,
      required int pageSize,
    });
typedef _DeleteHandler = Future<void> Function(String documentId);

class _FakeDocumentsApi extends DocumentsApi {
  _FakeDocumentsApi({
    required this.getDocumentsHandler,
    _DeleteHandler? deleteHandler,
  }) : deleteHandler = deleteHandler ?? ((_) async {}),
       super(Dio());

  final _GetDocumentsHandler getDocumentsHandler;
  final _DeleteHandler deleteHandler;

  @override
  Future<DocumentListResponse> getDocuments({
    int page = 1,
    int pageSize = 100,
  }) async {
    return getDocumentsHandler(page: page, pageSize: pageSize);
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    await deleteHandler(documentId);
  }
}
