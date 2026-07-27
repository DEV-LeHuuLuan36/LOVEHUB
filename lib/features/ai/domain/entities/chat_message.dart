import 'package:flutter/foundation.dart';

enum ChatRole { user, ai }

@immutable
class ChatMessage {
  final ChatRole role;
  final String text;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });

  bool get isUser => role == ChatRole.user;
  bool get isAi => role == ChatRole.ai;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          text == other.text &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(role, text, timestamp);
}
