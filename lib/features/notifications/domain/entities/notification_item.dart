import 'package:flutter/material.dart';

enum NotificationItemType {
  partnerCheckin,
  milestone,
  pet,
  pairing,
  reminder,
  other,
}

extension NotificationItemTypeExtension on NotificationItemType {
  String get key {
    switch (this) {
      case NotificationItemType.partnerCheckin:
        return 'partnerCheckin';
      case NotificationItemType.milestone:
        return 'milestone';
      case NotificationItemType.pet:
        return 'pet';
      case NotificationItemType.pairing:
        return 'pairing';
      case NotificationItemType.reminder:
        return 'reminder';
      case NotificationItemType.other:
        return 'other';
    }
  }

  static NotificationItemType fromKey(String key) {
    switch (key) {
      case 'partnerCheckin':
        return NotificationItemType.partnerCheckin;
      case 'milestone':
        return NotificationItemType.milestone;
      case 'pet':
        return NotificationItemType.pet;
      case 'pairing':
        return NotificationItemType.pairing;
      case 'reminder':
        return NotificationItemType.reminder;
      default:
        return NotificationItemType.other;
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationItemType.partnerCheckin:
        return Icons.favorite_rounded;
      case NotificationItemType.milestone:
        return Icons.emoji_events_rounded;
      case NotificationItemType.pet:
        return Icons.pets_rounded;
      case NotificationItemType.pairing:
        return Icons.link_rounded;
      case NotificationItemType.reminder:
        return Icons.alarm_rounded;
      case NotificationItemType.other:
        return Icons.notifications_rounded;
    }
  }

  Color iconColor(BuildContext context) {
    switch (this) {
      case NotificationItemType.partnerCheckin:
        return Colors.redAccent;
      case NotificationItemType.milestone:
        return Colors.amber;
      case NotificationItemType.pet:
        return Colors.orange;
      case NotificationItemType.pairing:
        return Colors.blueAccent;
      case NotificationItemType.reminder:
        return Colors.purpleAccent;
      case NotificationItemType.other:
        return Colors.grey;
    }
  }
}

@immutable
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final NotificationItemType type;
  final DateTime createdAt;
  final bool isRead;

  NotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    NotificationItemType? type,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.key,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: NotificationItemTypeExtension.fromKey(json['type'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
