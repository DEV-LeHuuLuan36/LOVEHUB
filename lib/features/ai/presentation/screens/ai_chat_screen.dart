import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/entities/ai_usage.dart';
import '../providers/ai_chat_providers.dart';
import '../providers/couple_ai_context_provider.dart';
import '../widgets/quick_questions_sheet.dart';

/// Single shared AI chat thread, scoped to `(coupleId, conversationId)`.
/// Both partners see the same messages in real time. The 20/day limit is
/// shared across all the couple's conversations.
class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({
    super.key,
    required this.coupleId,
    required this.conversationId,
    this.pendingPrompt,
  });

  final String coupleId;
  final String conversationId;

  /// If non-null, this prompt is sent automatically as the first message
  /// when the screen opens. Used by the "Quick questions" sheet on the
  /// conversation list.
  final String? pendingPrompt;

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();

  /// Suggested chips shown when the conversation is empty. Tapping a chip
  /// fills the field (does not auto-send) so the user can edit first.
  /// Values are translation keys resolved at render time.
  static const _suggestedPromptKeys = <String>[
    'ai.quickQuestions.q1',
    'ai.quickQuestions.q2',
    'ai.quickQuestions.q3',
    'ai.quickQuestions.q4',
  ];

  @override
  void initState() {
    super.initState();
    // If we were opened with a queued quick-question prompt, send it as
    // the first message after the first frame so the controllers are
    // mounted and the auth/usage streams are available.
    final pending = widget.pendingPrompt;
    if (pending != null && pending.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _send(pending);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  ({String coupleId, String conversationId}) get _args =>
      (coupleId: widget.coupleId, conversationId: widget.conversationId);

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          pos,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(pos);
      }
    });
  }

  /// Open the "Quick questions" sheet from the input-bar ✨. If the user
  /// picks a prompt, send it into the CURRENT conversation via the same
  /// `_send` path (consumeQuestion → 20/day limit → Firestore write →
  /// Groq call). On the conversation list, the same sheet is used but the
  /// picker there creates a new conversation first.
  Future<void> _openQuickAndSend() async {
    final prompt = await showQuickQuestionsSheet(context);
    if (prompt == null || prompt.isEmpty) return;
    if (!mounted) return;
    await _send(prompt);
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _textController.text).trim();
    if (text.isEmpty) return;

    final me = ref.read(authStateProvider).valueOrNull;
    if (me == null) return;

    // Optimistically clear the field; the message will appear in the
    // stream once Firestore writes it.
    _textController.clear();

    final ctx = ref.read(coupleAiContextProvider);
    final controller = ref.read(
      aiChatSendControllerProvider(_args).notifier,
    );
    final ok = await controller.send(
      text: text,
      senderUid: me.uid,
      context: ctx,
      localeCode: context.locale.languageCode,
    );

    if (!mounted) return;
    if (!ok) {
      final err = ref.read(aiChatSendControllerProvider(_args)).error;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        );
      }
    }
    _scrollToBottom();
  }

  Future<void> _deleteAndBack() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'ai.deleteChatTitle'.tr(),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'ai.deleteChatBody'.tr(),
          style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'common.cancel'.tr(),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'common.delete'.tr(),
              style: const TextStyle(
                color: Color(0xFFE53935),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    try {
      await ref
          .read(aiChatRepositoryProvider)
          .deleteConversation(widget.coupleId, widget.conversationId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ai.errors.deleteChat'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) return;
    // Pop the chat back to the conversation list.
    if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _newChatAndOpen() async {
    String? id;
    try {
      id = await ref
          .read(aiChatRepositoryProvider)
          .createConversation(widget.coupleId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ai.errors.createChat'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) return;
    // Replace the current route with the new chat. This keeps the back
    // stack sane: list -> new chat.
    context.pushReplacement(
      '/ai-coach/chat?conversationId=$id&coupleId=${widget.coupleId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(watchAiChatMessagesProvider(_args));
    final usageAsync = ref.watch(watchAiChatUsageProvider(widget.coupleId));
    final convAsync = ref.watch(watchAiConversationProvider(_args));
    final sendState = ref.watch(aiChatSendControllerProvider(_args));

    // Auto-scroll on new messages.
    ref.listen<AsyncValue<List<AiChatMessage>>>(
      watchAiChatMessagesProvider(_args),
      (prev, next) {
        final prevCount = prev?.valueOrNull?.length ?? 0;
        final nextCount = next.valueOrNull?.length ?? 0;
        if (nextCount > prevCount) _scrollToBottom();
      },
    );

    final messages = messagesAsync.valueOrNull ?? const <AiChatMessage>[];
    final usage = usageAsync.valueOrNull;
    final remaining = usage?.remaining ?? AiUsage.dailyLimit;
    final conversation = convAsync.valueOrNull;
    final title = conversation?.title ?? 'ai.conversationsTitle'.tr();

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              title: title,
              remaining: remaining,
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
              onNewChat: _newChatAndOpen,
              onDelete: messages.isEmpty ? null : _deleteAndBack,
            ),
            Expanded(
              child: messagesAsync.when(
                loading: () => const _LoadingList(),
                error: (e, _) => _ErrorList(message: e.toString()),
                data: (list) {
                  if (list.isEmpty) {
                    return _EmptyChat(suggestedKeys: _suggestedPromptKeys, onPick: (p) {
                      _textController.text = p;
                      _textController.selection = TextSelection.collapsed(
                        offset: p.length,
                      );
                      _inputFocus.requestFocus();
                    });
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: list.length +
                        (sendState.isSending ? 1 : 0) +
                        (sendState.error != null ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (sendState.error != null && i == 0) {
                        return _ErrorBanner(message: sendState.error!);
                      }
                      final offset = (sendState.error != null ? 1 : 0);
                      if (sendState.isSending && i == list.length + offset) {
                        return const _TypingBubble();
                      }
                      final msg = list[i - offset];
                      return _ChatBubble(
                        message: msg,
                        myUid: ref.read(authStateProvider).valueOrNull?.uid,
                      );
                    },
                  );
                },
              ),
            ),
            _InputBar(
              controller: _textController,
              focusNode: _inputFocus,
              isSending: sendState.isSending,
              remaining: remaining,
              onSend: _send,
              onQuick: _openQuickAndSend,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── HEADER ──────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.remaining,
    required this.onBack,
    required this.onNewChat,
    required this.onDelete,
  });
  final String title;
  final int remaining;
  final VoidCallback onBack;
  final VoidCallback onNewChat;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final dailyLimit = AiUsage.dailyLimit;
    final atLimit = remaining <= 0;
    final low = remaining > 0 && remaining <= 5;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
            tooltip: 'common.back'.tr(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'ai.poweredBy'.tr(),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: atLimit
                  ? const Color(0xFFE53935).withValues(alpha: 0.15)
                  : low
                      ? const Color(0xFFFFA000).withValues(alpha: 0.15)
                      : AppColors.gradientEnd.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: atLimit
                    ? const Color(0xFFE53935)
                    : low
                        ? const Color(0xFFFFA000)
                        : AppColors.gradientEnd,
                width: 1,
              ),
            ),
            child: Text(
              '$remaining/$dailyLimit ${'common.today'.tr()}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: atLimit
                    ? const Color(0xFFE53935)
                    : low
                        ? const Color(0xFFFFA000)
                        : AppColors.gradientEnd,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
            ),
            onSelected: (v) {
              if (v == 'new') onNewChat();
              if (v == 'delete' && onDelete != null) onDelete!();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'new',
                child: Row(
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'ai.newChat'.tr(),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Color(0xFFE53935),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'ai.deleteChat'.tr(),
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── CHAT BUBBLE ─────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.myUid});
  final AiChatMessage message;
  final String? myUid;

  bool get _isPartner => message.isUser &&
      message.senderUid != null &&
      message.senderUid != myUid;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final maxAiBubble = MediaQuery.of(context).size.width * 0.78;
    final maxUserBubble = MediaQuery.of(context).size.width * 0.72;

    final Widget bubble = isUser
        ? Container(
            constraints: BoxConstraints(maxWidth: maxUserBubble),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppSpacing.lg),
                topRight: const Radius.circular(4),
                bottomLeft: const Radius.circular(AppSpacing.lg),
                bottomRight: const Radius.circular(AppSpacing.lg),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gradientEnd.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          )
        : Container(
            constraints: BoxConstraints(maxWidth: maxAiBubble),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.lg),
                topRight: Radius.circular(AppSpacing.lg),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(AppSpacing.lg),
              ),
              border: const Border(
                left: BorderSide(color: AppColors.gradientEnd, width: 3),
              ),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          );

    final animatedBubble = isUser
        ? bubble
            .animate()
            .fadeIn(duration: 250.ms)
            .slideX(begin: 0.05, end: 0, duration: 250.ms, curve: Curves.easeOutCubic)
        : bubble
            .animate()
            .fadeIn(duration: 250.ms)
            .slideX(begin: -0.05, end: 0, duration: 250.ms, curve: Curves.easeOutCubic);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const _AIAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  _isPartner ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                if (_isPartner)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 4),
                    child: Text(
                      'common.partner'.tr(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                animatedBubble,
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AIAvatar extends StatelessWidget {
  const _AIAvatar();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text('🤖', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _AIAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.lg),
                topRight: Radius.circular(AppSpacing.lg),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(AppSpacing.lg),
              ),
              border: const Border(
                left: BorderSide(color: AppColors.gradientEnd, width: 3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.textSecondary,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .fadeIn(delay: Duration(milliseconds: i * 150))
                      .then()
                      .fadeOut(delay: Duration(milliseconds: i * 150 + 400)),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── INPUT BAR ──────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.remaining,
    required this.onSend,
    required this.onQuick,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final int remaining;
  final Future<void> Function([String? preset]) onSend;
  final VoidCallback onQuick;

  @override
  Widget build(BuildContext context) {
    final atLimit = remaining <= 0;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          _QuickQuestionsButton(onTap: onQuick),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !isSending,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: atLimit
                      ? 'ai.dailyLimitHint'.tr()
                      : 'ai.inputHint'.tr(),
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: (isSending || atLimit) ? null : () => onSend(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: (isSending || atLimit)
                    ? null
                    : AppColors.primaryGradient,
                color: (isSending || atLimit)
                    ? AppColors.textSecondary.withValues(alpha: 0.3)
                    : null,
                shape: BoxShape.circle,
                boxShadow: (isSending || atLimit)
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.gradientEnd.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward,
                      color: atLimit ? AppColors.textSecondary : Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SMALLER UI PIECES ──────────────────────────────────────────────────────
class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.suggestedKeys, required this.onPick});
  final List<String> suggestedKeys;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✨', style: TextStyle(fontSize: 36)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'ai.welcome'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ai.contextNote'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestedKeys
                  .map(
                    (key) {
                      final text = key.tr();
                      return GestureDetector(
                        onTap: () => onPick(text),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundCard,
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Text(
                            text,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.gradientEnd),
    );
  }
}

class _ErrorList extends StatelessWidget {
  const _ErrorList({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Could not load chat: $message',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: const Color(0xFFE53935).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFE53935),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFE53935),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable ✨ in the chat input bar. Opens the same
/// `showQuickQuestionsSheet` used by the AI Assistant list screen. On
/// the list screen, picking a prompt creates a new conversation; on the
/// chat screen, picking a prompt sends it into the current conversation.
class _QuickQuestionsButton extends StatelessWidget {
  const _QuickQuestionsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'ai.quickQuestions.title'.tr(),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppColors.pinkGlow(intensity: 8),
            ),
            child: const Text('✨', style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }
}
