import 'package:flutter/material.dart';
import '../../domain/entities/notification_item.dart';

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

/// A single notification row with icon, title, body, relative time,
/// and an unread indicator dot.
class NotificationItemRow extends StatelessWidget {
  const NotificationItemRow({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDismiss,
    required this.formatTime,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final String Function(DateTime) formatTime;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: item.isRead
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.05),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.type.iconColor(context).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.type.icon,
                  color: item.type.iconColor(context),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: item.isRead
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!item.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatTime(item.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
