import 'dart:math' as math;
import 'dart:ui';

import 'package:documind_ai/core/layout/responsive_breakpoints.dart';
import 'package:documind_ai/core/theme/app_spacing.dart';
import 'package:documind_ai/core/theme/theme_extensions.dart';
import 'package:documind_ai/features/chat/models/chat_models.dart';
import 'package:documind_ai/features/chat/providers/chat_controller.dart';
import 'package:documind_ai/features/chat/widgets/ai_response_bubble.dart';
import 'package:documind_ai/features/chat/widgets/ai_typing_indicator.dart';
import 'package:documind_ai/features/chat/widgets/chat_empty_state.dart';
import 'package:documind_ai/features/chat/widgets/chat_input_bar.dart';
import 'package:documind_ai/features/chat/widgets/user_question_bubble.dart';
import 'package:documind_ai/features/library/providers/document_list_provider.dart';
import 'package:documind_ai/shared/widgets/accessibility_focus_ring.dart';
import 'package:documind_ai/shared/widgets/app_snackbar.dart';
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

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final TextEditingController _inputController;
  late final AnimationController _fabController;
  final Set<String> _pendingAnimatedMessageIds = <String>{};
  bool _showScrollFab = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _inputController = TextEditingController();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider.notifier).load(widget.documentId);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
      return;
    }
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    final distanceToBottom = maxScroll - current;
    final shouldShow = distanceToBottom > 200;
    if (shouldShow != _showScrollFab) {
      setState(() => _showScrollFab = shouldShow);
      if (shouldShow) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    }
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _inputController.dispose();
    _fabController.dispose();
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
        showPersistentErrorSnackBar(
          context,
          tokens,
          next.errorMessage!,
          onRetry: next.lastFailedQuestion == null
              ? null
              : () {
                  ref
                      .read(chatControllerProvider.notifier)
                      .retryLastFailedSend();
                },
        );
      }

      if (next.warningMessage != null &&
          next.warningMessage != previous?.warningMessage) {
        showWarningSnackBar(context, tokens, next.warningMessage!);
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

    final title = (chatState.documentId == null || chatState.documentTitle.isEmpty)
        ? 'Select Document'
        : chatState.documentTitle;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: tokens.colors.surfacePrimary,
      appBar: _buildFrostedAppBar(context, tokens, title),
      body: SafeArea(
        top: false,
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

  PreferredSizeWidget _buildFrostedAppBar(
    BuildContext context,
    DocuMindTokens tokens,
    String title,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: tokens.colors.surfacePrimary.withValues(alpha: 0.75),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              title: AccessibilityFocusRing(
                borderRadius: AppSpacing.sm,
                child: Semantics(
                  button: true,
                  label: 'Select active document. $title',
                  child: InkWell(
                    key: const Key('chat-document-selector-button'),
                    onTap: _openDocumentSelector,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.colors.surfaceTertiary.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: tokens.colors.borderDefault.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 15,
                            color: tokens.colors.accentPrimary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: tokens.colors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const ExcludeSemantics(
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                AccessibilityFocusRing(
                  borderRadius: 22,
                  child: IconButton(
                    key: const Key('chat-new-conversation-button'),
                    tooltip: 'New conversation',
                    onPressed: _confirmNewConversation,
                    icon: const ExcludeSemantics(
                      child: Icon(Icons.add_comment_outlined),
                    ),
                  ),
                ),
                AccessibilityFocusRing(
                  borderRadius: 22,
                  child: PopupMenuButton<_ChatAction>(
                    key: const Key('chat-overflow-menu'),
                    tooltip: 'Chat options',
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
                ),
              ],
            ),
          ),
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
          child: Stack(
            children: [
              chatState.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: tokens.colors.accentPrimary,
                      ),
                    )
                  : _buildMessagePane(context, chatState),

              // Scroll-to-bottom FAB
              Positioned(
                right: AppSpacing.lg,
                bottom: AppSpacing.sm,
                child: FadeTransition(
                  opacity: _fabController,
                  child: ScaleTransition(
                    scale: _fabController,
                    child: _showScrollFab
                        ? GestureDetector(
                            onTap: _scrollToBottom,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tokens.colors.surfaceSecondary,
                                border: Border.all(
                                  color: tokens.colors.borderDefault,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: tokens.colors.textSecondary,
                                size: 22,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
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
          enabled: chatState.documentId != null && !chatState.isRateLimited,
          hintText: chatState.documentId == null
              ? 'Select a document to ask questions'
              : null,
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
                final documentsAsync = ref
                    .watch(documentListProvider)
                    .documents;
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
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;
    await ref.read(documentListProvider.notifier).refresh();
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: tokens.colors.surfaceSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, child) {
            final documentsAsync = ref.watch(documentListProvider).documents;
            return documentsAsync.when(
              data: (response) {
                final readyDocuments = response.items
                    .where((doc) => doc.status == 'ready')
                    .toList(growable: false);

                if (readyDocuments.isEmpty) {
                  return SizedBox(
                    key: const Key('chat-document-selector-sheet-empty'),
                    height: 200,
                    child: Center(
                      child: Text(
                        'No ready documents available.',
                        style: TextStyle(color: tokens.colors.textSecondary),
                      ),
                    ),
                  );
                }

                return SafeArea(
                  child: Column(
                    key: const Key('chat-document-selector-sheet'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: tokens.colors.borderDefault,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.md,
                          AppSpacing.xl,
                          AppSpacing.sm,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Switch Document',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: tokens.colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        child: ListView.builder(
                          key: const Key('chat-document-selector-sheet-list'),
                          shrinkWrap: true,
                          itemCount: readyDocuments.length,
                          itemBuilder: (context, index) {
                            final document = readyDocuments[index];
                            final isActive = document.id == widget.documentId;
                            return ListTile(
                              key: Key('chat-document-option-${document.id}'),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? tokens.colors.accentPrimary
                                            .withValues(alpha: 0.15)
                                      : tokens.colors.surfaceTertiary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.description_outlined,
                                  size: 18,
                                  color: isActive
                                      ? tokens.colors.accentPrimary
                                      : tokens.colors.textSecondary,
                                ),
                              ),
                              title: Text(
                                document.title,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isActive
                                      ? tokens.colors.textPrimary
                                      : tokens.colors.textSecondary,
                                ),
                              ),
                              trailing: isActive
                                  ? Icon(
                                      Icons.check_circle_rounded,
                                      color: tokens.colors.accentPrimary,
                                      size: 20,
                                    )
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
                      ),
                    ],
                  ),
                );
              },
              error: (error, stackTrace) {
                return SizedBox(
                  key: const Key('chat-document-selector-sheet-error'),
                  height: 200,
                  child: Center(child: Text('Unable to load documents.')),
                );
              },
              loading: () {
                return SizedBox(
                  key: const Key('chat-document-selector-sheet-loading'),
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
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;
    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: tokens.colors.surfaceSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Start new conversation?'),
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
    final tokens = Theme.of(context).extension<DocuMindTokens>()!;
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
      backgroundColor: tokens.colors.surfaceSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        if (sessions.isEmpty) {
          return SizedBox(
            key: const Key('chat-conversation-history-sheet-empty'),
            height: 200,
            child: Center(
              child: Text(
                'No previous conversations yet.',
                style: TextStyle(color: tokens.colors.textSecondary),
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.colors.borderDefault,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Conversation History',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens.colors.textPrimary,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                key: const Key('chat-conversation-history-sheet-list'),
                shrinkWrap: true,
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  final subtitle = _formatConversationLabel(session.updatedAt);
                  return ListTile(
                    key: Key('chat-conversation-option-${session.id}'),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: tokens.colors.surfaceTertiary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: tokens.colors.accentPrimary,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      'Conversation ${index + 1}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: tokens.colors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: tokens.colors.textTertiary,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await controller.activateConversation(session.id);
                    },
                  );
                },
              ),
            ),
          ],
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

    // ── No document selected ──────────────────────────────────────────────
    if (chatState.documentId == null) {
      return ChatEmptyState(
        documentTitle: chatState.documentTitle,
        onSelectDocument: _openDocumentSelector,
      );
    }

    // ── Document still processing ────────────────────────────────────────
    if (!chatState.isDocumentReady) {
      return _ProcessingState(tokens: tokens);
    }

    // ── Empty state ──────────────────────────────────────────────────────
    if (chatState.messages.isEmpty && !chatState.isStreaming) {
      return ChatEmptyState(
        documentTitle: chatState.documentTitle,
        onSuggestionTap: (suggestion) {
          _inputController.text = suggestion;
          ref.read(chatControllerProvider.notifier).updateDraft(suggestion);
          ref.read(chatControllerProvider.notifier).send(suggestion);
        },
      );
    }

    // ── Message list ─────────────────────────────────────────────────────
    return ListView.builder(
      key: const Key('chat-message-list'),
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.of(context).padding.top + kToolbarHeight + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      itemCount: chatState.messages.length + (chatState.isStreaming ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= chatState.messages.length) {
          return const AiTypingIndicator();
        }

        final message = chatState.messages[index];
        final isUserMessage = message.role == ChatRole.user;

        final bubble = isUserMessage
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

        // User messages slide from the right, AI from the left
        final slideBegin = isUserMessage
            ? const Offset(0.08, 0)
            : const Offset(-0.08, 0);

        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0, end: 1),
          child: bubble,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: FractionalTranslation(
                translation: Offset.lerp(slideBegin, Offset.zero, value)!,
                child: child,
              ),
            );
          },
        );
      },
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    } else {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToBottomIfNearEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scrollController.hasClients ||
          !_scrollController.position.hasContentDimensions) {
        return;
      }

      final maxScroll = _scrollController.position.maxScrollExtent;
      final current = _scrollController.offset;
      final distanceToBottom = maxScroll - current;

      if (distanceToBottom <= 180) {
        _scrollToBottom();
      }
    });
  }
}

// ─── Processing / Not-ready state ────────────────────────────────────────────

class _ProcessingState extends StatefulWidget {
  const _ProcessingState({required this.tokens});

  final DocuMindTokens tokens;

  @override
  State<_ProcessingState> createState() => _ProcessingStateState();
}

class _ProcessingStateState extends State<_ProcessingState>
    with TickerProviderStateMixin {
  late final AnimationController _rotateController;
  late final AnimationController _breathController;
  late final Animation<double> _breathAnim;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _breathAnim = CurvedAnimation(
      parent: _breathController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final theme = Theme.of(context);
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rotating scanner ring
                  if (!disableAnimations)
                    AnimatedBuilder(
                      animation: _rotateController,
                      builder: (context, _) {
                        return Transform.rotate(
                          angle: _rotateController.value * 2 * math.pi,
                          child: CustomPaint(
                            size: const Size(120, 120),
                            painter: _ScannerRingPainter(
                              color: tokens.colors.accentPrimary,
                            ),
                          ),
                        );
                      },
                    ),

                  // Pulsing glow
                  AnimatedBuilder(
                    animation: disableAnimations
                        ? kAlwaysCompleteAnimation
                        : _breathAnim,
                    builder: (context, _) {
                      final t = disableAnimations ? 0.5 : _breathAnim.value;
                      return Container(
                        width: 70 + t * 8,
                        height: 70 + t * 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              tokens.colors.accentWarning.withValues(
                                alpha: 0.3 + t * 0.15,
                              ),
                              tokens.colors.surfacePrimary.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.colors.surfaceSecondary,
                      border: Border.all(
                        color: tokens.colors.accentWarning.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.hourglass_top_rounded,
                      color: tokens.colors.accentWarning,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            Text(
              'Processing your document…',
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

            const SizedBox(height: AppSpacing.xl),

            FilledButton.icon(
              key: const Key('chat-back-to-library-button'),
              onPressed: () => context.go('/library'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to Library'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerRingPainter extends CustomPainter {
  const _ScannerRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Bright arc (80% of circle)
    paint.shader = SweepGradient(
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.8),
        color,
      ],
      stops: const [0.0, 0.6, 0.8],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * 0.8,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
