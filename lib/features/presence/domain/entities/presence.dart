import 'package:flutter/foundation.dart';

@immutable
class Presence {
  final bool isOnline;
  final DateTime? lastSeen;

  const Presence({
    required this.isOnline,
    this.lastSeen,
  });

  static const offline = Presence(isOnline: false);

  String relativeLastSeen() {
    final seen = lastSeen;
    if (seen == null) return '';
    final diff = DateTime.now().difference(seen);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
