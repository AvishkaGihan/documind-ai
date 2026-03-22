import 'package:documind_ai/core/theme/app_theme.dart';
import 'package:documind_ai/features/chat/widgets/chat_input_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'send button is disabled when input is empty and enabled when text exists',
    (WidgetTester tester) async {
      final controller = TextEditingController();
      var sendCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ChatInputBar(
              controller: controller,
              onChanged: (_) {},
              onSend: () {
                sendCalls += 1;
              },
              isSending: false,
            ),
          ),
        ),
      );

      final sendButton = find.byKey(const Key('chat-send-button'));
      expect(sendButton, findsOneWidget);

      final disabledButton = tester.widget<IconButton>(sendButton);
      expect(disabledButton.onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('chat-input-text-field')),
        'Hello',
      );
      await tester.pump(const Duration(milliseconds: 40));

      final enabledButton = tester.widget<IconButton>(sendButton);
      expect(enabledButton.onPressed, isNotNull);

      await tester.tap(sendButton);
      await tester.pump(const Duration(milliseconds: 20));

      expect(sendCalls, 1);
    },
  );

  testWidgets('input bar disables text field and send when disabled', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'Question');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: ChatInputBar(
            controller: controller,
            onChanged: (_) {},
            onSend: () {},
            isSending: false,
            enabled: false,
          ),
        ),
      ),
    );

    final textField = tester.widget<TextField>(
      find.byKey(const Key('chat-input-text-field')),
    );
    expect(textField.enabled, isFalse);

    final sendButton = tester.widget<IconButton>(
      find.byKey(const Key('chat-send-button')),
    );
    expect(sendButton.onPressed, isNull);
  });

  testWidgets('send button exposes required semantics label', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'Question');

    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: ChatInputBar(
            controller: controller,
            onChanged: (_) {},
            onSend: () {},
            isSending: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.bySemanticsLabel('Send question'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('keyboard tab traversal keeps send control focusable', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'Question');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: FocusTraversalGroup(
            child: ChatInputBar(
              controller: controller,
              onChanged: (_) {},
              onSend: () {},
              isSending: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 160));

    expect(find.byKey(const Key('chat-send-focus-ring')), findsOneWidget);
    expect(find.byKey(const Key('chat-send-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
