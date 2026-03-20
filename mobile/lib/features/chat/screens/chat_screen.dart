import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:documind_ai/features/chat/providers/chat_controller.dart';
import 'package:documind_ai/features/chat/widgets/ai_response_bubble.dart';
import 'package:documind_ai/features/chat/widgets/ai_typing_indicator.dart';
import 'package:documind_ai/features/chat/widgets/chat_input_bar.dart';
import 'package:documind_ai/features/chat/widgets/user_question_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.documentId, super.key});

  final String documentId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final ScrollController _scrollController;
  late final TextEditingController _inputController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _inputController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider.notifier).load(widget.documentId);
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) {
      ref.read(chatControllerProvider.notifier).load(widget.documentId);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;
    final chatState = ref.watch(chatControllerProvider);

    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      if (next.announcement != null &&
          next.announcement != previous?.announcement) {
        final textDirection = Directionality.of(context);
        SemanticsService.sendAnnouncement(
          View.of(context),
          next.announcement!,
          textDirection,
        );
        ref.read(chatControllerProvider.notifier).clearAnnouncement();
      }

      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(next.errorMessage!),
              backgroundColor: tokens.colors.accentError,
              duration: const Duration(days: 1),
            ),
          );
      }

      final hadDifferentLength =
          previous == null || previous.messages.length != next.messages.length;
      final streamingUpdated =
          previous?.isStreaming == true && next.isStreaming;
      if (hadDifferentLength || streamingUpdated) {
        _scrollToBottomIfNearEnd();
      }
    });

    if (_inputController.text != chatState.inputDraft) {
      _inputController.value = TextEditingValue(
        text: chatState.inputDraft,
        selection: TextSelection.collapsed(offset: chatState.inputDraft.length),
      );
    }

    final title = chatState.documentTitle.isEmpty
        ? 'Chat'
        : chatState.documentTitle;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(title), centerTitle: false),
      backgroundColor: tokens.colors.surfacePrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: chatState.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: tokens.colors.accentPrimary,
                      ),
                    )
                  : _buildMessagePane(context, chatState),
            ),
            ChatInputBar(
              controller: _inputController,
              onChanged: (value) {
                ref.read(chatControllerProvider.notifier).updateDraft(value);
              },
              onSend: () {
                final question = _inputController.text;
                ref.read(chatControllerProvider.notifier).send(question);
              },
              isSending: chatState.isStreaming,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagePane(BuildContext context, ChatState chatState) {
    final theme = Theme.of(context);
    final tokens = theme.extension<DocuMindTokens>()!;

    if (!chatState.isDocumentReady) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'This document is still processing.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: tokens.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Please return to the Library and try again once it is ready.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('chat-back-to-library-button'),
              onPressed: () => context.go('/library'),
              child: const Text('Back to Library'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: const Key('chat-message-list'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      itemCount: chatState.messages.length + (chatState.isStreaming ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= chatState.messages.length) {
          return const AiTypingIndicator();
        }

        final message = chatState.messages[index];
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutBack,
          tween: Tween<double>(begin: 0.94, end: 1),
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0, 1),
              child: Transform.scale(
                scale: value,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            );
          },
          child: message.role == ChatRole.user
              ? UserQuestionBubble(text: message.content)
              : AiResponseBubble(
                  message: message,
                  expandedPages: chatState.expandedCitationPages,
                  citationExcerpts: chatState.citationExcerpts,
                  onToggleCitation: (page) {
                    ref
                        .read(chatControllerProvider.notifier)
                        .toggleCitation(page);
                  },
                ),
        );
      },
    );
  }

  void _scrollToBottomIfNearEnd() {
    if (!_scrollController.hasClients) {
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    final distanceToBottom = maxScroll - current;

    if (distanceToBottom > 180) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }
}
