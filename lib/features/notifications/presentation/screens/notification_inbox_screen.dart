import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/entities/notification_item.dart';
import '../providers/inbox_providers.dart';
import '../widgets/notification_item_row.dart';

class NotificationInboxScreen extends ConsumerWidget {
  const NotificationInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxState = ref.watch(notificationInboxProvider);
    final isVi = context.locale.languageCode == 'vi';

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'notifications.inbox.title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (!inboxState.isEmpty && inboxState.unreadCount > 0)
            TextButton(
              onPressed: () {
                ref.read(notificationInboxProvider.notifier).markAllAsRead();
              },
              child: Text(
                'notifications.inbox.markAllRead'.tr(),
                style: const TextStyle(
                  color: AppColors.gradientEnd,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: AppColors.backgroundCard,
            onSelected: (value) async {
              if (value == 'clear') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.backgroundCard,
                    title: Text(
                      'notifications.inbox.clearAll'.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                    content: Text(
                      'notifications.inbox.clearAllConfirm'.tr(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(
                          'common.cancel'.tr(),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(
                          'common.delete'.tr(),
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(notificationInboxProvider.notifier).clearAll();
                }
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep_outlined,
                        color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'notifications.inbox.clearAll'.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(context, ref, inboxState, isVi),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    NotificationInboxState state,
    bool isVi,
  ) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.gradientEnd,
        ),
      );
    }

    if (state.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 72,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'notifications.inbox.empty'.tr(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final formatTime = isVi ? formatRelativeTimeVi : formatRelativeTimeEn;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        return NotificationItemRow(
          item: item,
          formatTime: formatTime,
          onTap: () {
            if (!item.isRead) {
              ref.read(notificationInboxProvider.notifier).markAsRead(item.id);
            }
            _navigateByType(context, item.type);
          },
          onDismiss: () {
            ref.read(notificationInboxProvider.notifier).delete(item.id);
          },
        );
      },
    );
  }

  void _navigateByType(BuildContext context, NotificationItemType type) {
    // Navigation is handled by the notification tap handler in main.dart
    // For now, just dismiss the screen
    Navigator.of(context).pop();
  }
}

String formatRelativeTimeVi(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inSeconds < 60) {
    return 'Vừa xong';
  } else if (diff.inMinutes < 60) {
    final count = diff.inMinutes;
    return '$count phút trước';
  } else if (diff.inHours < 24) {
    final count = diff.inHours;
    return '$count giờ trước';
  } else if (diff.inDays < 7) {
    final count = diff.inDays;
    return '$count ngày trước';
  } else {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

String formatRelativeTimeEn(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inSeconds < 60) {
    return 'Just now';
  } else if (diff.inMinutes < 60) {
    final count = diff.inMinutes;
    return '$count min ago';
  } else if (diff.inHours < 24) {
    final count = diff.inHours;
    return '$count hr ago';
  } else if (diff.inDays < 7) {
    final count = diff.inDays;
    return '$count day${count > 1 ? 's' : ''} ago';
  } else {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }
}
