import 'package:flutter/foundation.dart';

/// A saved AI chat thread for a couple, shown in the sidebar / list.
/// Persisted under `aiChats/{coupleId}/conversations/{conversationId}`.
@immutable
class AiConversation {
  const AiConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessagePreview,
  });

  final String id;

  /// Display title. Auto-derived from the first user message (truncated
  /// to ~40 chars) when the first message is sent, otherwise "New chat".
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Short preview of the most recent message in this thread (truncated
  /// to ~80 chars). Empty string when the conversation has no messages
  /// yet.
  final String lastMessagePreview;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiConversation &&
          id == other.id &&
          title == other.title &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          lastMessagePreview == other.lastMessagePreview;

  @override
  int get hashCode =>
      Object.hash(id, title, createdAt, updatedAt, lastMessagePreview);
}
