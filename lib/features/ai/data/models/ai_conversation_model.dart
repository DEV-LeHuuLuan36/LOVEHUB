import '../../domain/entities/ai_conversation.dart';

/// Firestore model for [AiConversation]. Persists to and from
/// `aiChats/{coupleId}/conversations/{conversationId}`.
class AiConversationModel extends AiConversation {
  const AiConversationModel({
    required super.id,
    required super.title,
    required super.createdAt,
    required super.updatedAt,
    required super.lastMessagePreview,
  });

  factory AiConversationModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final now = DateTime.now();
    return AiConversationModel(
      id: id,
      title: (data['title'] as String?) ?? 'New chat',
      createdAt: _parseTimestamp(data['createdAt']) ?? now,
      updatedAt: _parseTimestamp(data['updatedAt']) ?? now,
      lastMessagePreview: (data['lastMessagePreview'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastMessagePreview': lastMessagePreview,
    };
  }

  /// Best-effort timestamp parser (mirrors the pattern used by
  /// `AiChatMessageModel`).
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final dyn = value as dynamic;
    try {
      final seconds = dyn.seconds as int?;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } catch (_) {/* not a Timestamp */}
    if (value is Map) {
      final millis = value['_seconds'] as int?;
      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis * 1000);
      }
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
