import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../domain/entities/ai_conversation.dart';
import '../providers/ai_chat_providers.dart';
import '../widgets/quick_questions_sheet.dart';
import 'ai_chat_screen.dart';

/// Sidebar / list of all AI chat conversations for the couple, newest
/// `updatedAt` first. Shared in real time between both partners.
class AIConversationsScreen extends ConsumerWidget {
  const AIConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupleId = ref.watch(currentCoupleIdProvider);

    if (coupleId == null || coupleId.isEmpty) {
      return const _NotInCoupleState();
    }

    final conversationsAsync = ref.watch(watchAiConversationsProvider(coupleId));

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              onNew: () => _newAndOpen(context, ref, coupleId),
              onQuick: () => _onQuick(context, ref, coupleId),
            ),
            Expanded(
              child: conversationsAsync.when(
                loading: () => const _LoadingList(),
                error: (e, _) => _ErrorList(message: e.toString()),
                data: (list) {
                  if (list.isEmpty) {
                    return _EmptyState(
                      onNew: () => _newAndOpen(context, ref, coupleId),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final c = list[i];
                      return _ConversationTile(
                        key: ValueKey(c.id),
                        conversation: c,
                        onTap: () => _open(context, coupleId, c.id),
                        onDelete: () =>
                            _confirmDelete(context, ref, coupleId, c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: conversationsAsync.maybeWhen(
        data: (list) => list.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _newAndOpen(context, ref, coupleId),
                backgroundColor: AppColors.gradientEnd,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.edit_rounded),
                label: Text(
                  'ai.newChat'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
        orElse: () => null,
      ),
    );
  }

  Future<void> _newAndOpen(
    BuildContext context,
    WidgetRef ref,
    String coupleId,
  ) async {
    String? id;
    try {
      id = await ref.read(aiChatRepositoryProvider).createConversation(coupleId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ai.errors.createChat'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!context.mounted) return;
    _open(context, coupleId, id);
  }

  void _open(
    BuildContext context,
    String coupleId,
    String conversationId, {
    String? pendingPrompt,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AIChatScreen(
          coupleId: coupleId,
          conversationId: conversationId,
          pendingPrompt: pendingPrompt,
        ),
      ),
    );
  }

  /// Show the "Quick questions" sheet, then create a new conversation and
  /// push the chat with the chosen prompt queued to be sent as the first
  /// message. The 20/day limit is still applied (the same
  /// `aiChatSendController` / `consumeQuestion` path is used).
  Future<void> _onQuick(
    BuildContext context,
    WidgetRef ref,
    String coupleId,
  ) async {
    final prompt = await showQuickQuestionsSheet(context);
    if (prompt == null || prompt.isEmpty) return;
    if (!context.mounted) return;

    String? id;
    try {
      id = await ref
          .read(aiChatRepositoryProvider)
          .createConversation(coupleId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ai.errors.createChat'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!context.mounted) return;
    _open(context, coupleId, id, pendingPrompt: prompt);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String coupleId,
    AiConversation c,
  ) async {
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
          'ai.deleteChatWithTitle'.tr(args: [c.title]),
          style: const TextStyle(
            color: AppColors.textPrimary,
            height: 1.4,
          ),
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
    try {
      await ref
          .read(aiChatRepositoryProvider)
          .deleteConversation(coupleId, c.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ai.errors.delete'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ─── HEADER ──────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.onNew, required this.onQuick});
  final VoidCallback onNew;
  final VoidCallback onQuick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
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
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onQuick,
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
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ai.assistantTitle'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              'ai.newChat'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.gradientEnd,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TILE ────────────────────────────────────────────────────────────────────
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onDelete,
  });

  final AiConversation conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss-${conversation.id}'),
      direction: DismissDirection.endToStart,
      background: _DismissBackground(),
      confirmDismiss: (_) async {
        onDelete();
        // The list stream will remove the row on its own; tell Dismissible
        // to dismiss immediately so the row visibly leaves the screen.
        return true;
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.borderSubtle, width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        conversation.lastMessagePreview.isEmpty
                            ? 'ai.noMessages'.tr()
                            : conversation.lastMessagePreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary.withValues(alpha: 0.8),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(conversation.updatedAt),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      onSelected: (v) {
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Color(0xFFE53935),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'common.delete'.tr(),
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
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return DateFormat('h:mm a').format(dt);
    if (diff == 1) return 'common.timeAgo.yesterday'.tr();
    if (diff < 7) return DateFormat('EEE').format(dt);
    return DateFormat('M/d').format(dt);
  }
}

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_rounded, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            'common.delete'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SMALLER UI PIECES ──────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNew});
  final VoidCallback onNew;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✨', style: TextStyle(fontSize: 36)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'ai.noConversations'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ai.noConversationsHint'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: onNew,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gradientEnd,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'ai.newChat'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
          'Could not load conversations: $message',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        ),
      ),
    );
  }
}

class _NotInCoupleState extends StatelessWidget {
  const _NotInCoupleState();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'ai.linkToUse'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}
