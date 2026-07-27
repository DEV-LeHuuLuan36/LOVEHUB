import 'package:flutter/foundation.dart';

/// A single message in the shared AI chat thread.
///
/// Persisted under `aiChats/{coupleId}/messages/{messageId}` so both
/// partners see the same conversation in real time.
@immutable
class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.senderUid,
  });

  final String id;

  /// `'user'` for messages sent by either partner, `'assistant'` for AI
  /// replies. Stored as a String (not enum) so it's robust to future
  /// schema changes.
  final String role;

  final String text;

  /// Required for `'user'` messages (which partner sent it). Always `null`
  /// for `'assistant'` messages.
  final String? senderUid;

  final DateTime createdAt;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiChatMessage &&
          id == other.id &&
          role == other.role &&
          text == other.text &&
          senderUid == other.senderUid &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, role, text, senderUid, createdAt);
}
