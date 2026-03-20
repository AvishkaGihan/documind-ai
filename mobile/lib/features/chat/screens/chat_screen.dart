import 'package:documind_ai/core/layout/responsive_breakpoints.dart';
import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:documind_ai/features/chat/providers/chat_controller.dart';
import 'package:documind_ai/features/chat/widgets/ai_response_bubble.dart';
import 'package:documind_ai/features/chat/widgets/ai_typing_indicator.dart';
import 'package:documind_ai/features/chat/widgets/chat_input_bar.dart';
import 'package:documind_ai/features/chat/widgets/user_question_bubble.dart';
import 'package:documind_ai/features/library/providers/document_list_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _ChatAction { conversationHistory }

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.documentId, super.key});

  final String documentId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final ScrollController _scrollController;
  late final TextEditingController _inputController;
  final Set<String> _pendingAnimatedMessageIds = <String>{};

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(chatControllerProvider.notifier).load(widget.documentId);
      });
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

      if (previous != null) {
        final previousIds = previous.messages
            .map((message) => message.id)
            .toSet();
        for (final message in next.messages) {
          if (!previousIds.contains(message.id)) {
            _pendingAnimatedMessageIds.add(message.id);
          }
        }
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
      appBar: AppBar(
        centerTitle: false,
        title: InkWell(
          key: const Key('chat-document-selector-button'),
          onTap: _openDocumentSelector,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            key: const Key('chat-new-conversation-button'),
            tooltip: 'New Conversation',
            onPressed: _confirmNewConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          PopupMenuButton<_ChatAction>(
            key: const Key('chat-overflow-menu'),
            onSelected: (action) async {
              await _openConversationHistory();
            },
            itemBuilder: (context) => const [
              PopupMenuItem<_ChatAction>(
                value: _ChatAction.conversationHistory,
                key: Key('chat-menu-conversation-history'),
                child: Text('Conversation history'),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: tokens.colors.surfacePrimary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final widthClass = classifyScreenWidth(width);

            if (widthClass.isTablet) {
              return Row(
                key: const Key('chat-tablet-split-layout'),
                children: [
                  Flexible(flex: 4, child: _buildTabletDocumentPane(context)),
                  const VerticalDivider(width: 1),
                  Flexible(
                    flex: 7,
                    child: _buildChatPane(
                      context: context,
                      chatState: chatState,
                      key: const Key('chat-tablet-chat-pane'),
                    ),
                  ),
                ],
              );
            }

            return _buildChatPane(context: context, chatState: chatState);
          },
        ),
      ),
    );
  }

  Widget _buildChatPane({
    required BuildContext context,
    required ChatState chatState,
    Key? key,
  }) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return Column(
      key: key,
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
    );
  }

  Widget _buildTabletDocumentPane(BuildContext context) {
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;

    return DecoratedBox(
      key: const Key('chat-tablet-document-pane'),
      decoration: BoxDecoration(color: tokens.colors.surfaceSecondary),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ready Documents',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final documentsAsync = ref.watch(documentListProvider);
                return documentsAsync.when(
                  data: (response) {
                    final readyDocuments = response.items
                        .where((doc) => doc.status == 'ready')
                        .toList(growable: false);

                    if (readyDocuments.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Text('No ready documents available.'),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: readyDocuments.length,
                      itemBuilder: (context, index) {
                        final document = readyDocuments[index];
                        return ListTile(
                          key: Key('chat-tablet-document-${document.id}'),
                          title: Text(
                            document.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected: document.id == widget.documentId,
                          onTap: () {
                            if (document.id != widget.documentId) {
                              context.go('/chat/${document.id}');
                            }
                          },
                        );
                      },
                    );
                  },
                  error: (error, stackTrace) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Text('Unable to load documents.'),
                      ),
                    );
                  },
                  loading: () {
                    return Center(
                      child: CircularProgressIndicator(
                        color: tokens.colors.accentPrimary,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDocumentSelector() async {
    await ref.read(documentListProvider.notifier).refresh();
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, child) {
            final documentsAsync = ref.watch(documentListProvider);
            return documentsAsync.when(
              data: (response) {
                final readyDocuments = response.items
                    .where((doc) => doc.status == 'ready')
                    .toList(growable: false);

                if (readyDocuments.isEmpty) {
                  return const SizedBox(
                    key: Key('chat-document-selector-sheet'),
                    height: 200,
                    child: Center(child: Text('No ready documents available.')),
                  );
                }

                return SafeArea(
                  child: ListView.builder(
                    key: const Key('chat-document-selector-sheet'),
                    itemCount: readyDocuments.length,
                    itemBuilder: (context, index) {
                      final document = readyDocuments[index];
                      return ListTile(
                        key: Key('chat-document-option-${document.id}'),
                        title: Text(document.title),
                        trailing: document.id == widget.documentId
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          if (document.id != widget.documentId) {
                            context.go('/chat/${document.id}');
                          }
                        },
                      );
                    },
                  ),
                );
              },
              error: (error, stackTrace) {
                return const SizedBox(
                  key: Key('chat-document-selector-sheet'),
                  height: 200,
                  child: Center(child: Text('Unable to load documents.')),
                );
              },
              loading: () {
                final tokens = Theme.of(context).extension<DocuMindTokens>()!;
                return SizedBox(
                  key: const Key('chat-document-selector-sheet'),
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: tokens.colors.accentPrimary,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _confirmNewConversation() async {
    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Start a new conversation?'),
          content: const Text(
            'This clears the current chat view and starts a fresh conversation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('chat-confirm-new-conversation-button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Start New'),
            ),
          ],
        );
      },
    );

    if (shouldStart != true || !mounted) {
      return;
    }

    await ref.read(chatControllerProvider.notifier).startNewConversation();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Conversation cleared.'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openConversationHistory() async {
    final controller = ref.read(chatControllerProvider.notifier);
    List<ConversationSession> sessions;
    try {
      sessions = await controller.listConversationHistory();
    } on Exception {
      return;
    }

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        if (sessions.isEmpty) {
          return const SizedBox(
            key: Key('chat-conversation-history-sheet'),
            height: 200,
            child: Center(child: Text('No previous conversations yet.')),
          );
        }

        return ListView.builder(
          key: const Key('chat-conversation-history-sheet'),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            final subtitle = _formatConversationLabel(session.updatedAt);
            return ListTile(
              key: Key('chat-conversation-option-${session.id}'),
              title: Text('Conversation ${index + 1}'),
              subtitle: Text(subtitle),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await controller.activateConversation(session.id);
              },
            );
          },
        );
      },
    );
  }

  String _formatConversationLabel(DateTime timestamp) {
    final utc = timestamp.toUtc();
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    return 'Updated $month/$day ${utc.year} $hour:$minute UTC';
  }

  Widget _buildMessagePane(BuildContext context, ChatState chatState) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

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
        final bubble = message.role == ChatRole.user
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
              );

        final shouldAnimate =
            !reduceMotion && _pendingAnimatedMessageIds.remove(message.id);
        if (!shouldAnimate) {
          return bubble;
        }

        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          tween: Tween<double>(begin: 0.97, end: 1),
          child: bubble,
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
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduceMotion) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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
