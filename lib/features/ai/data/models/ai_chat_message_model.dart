import '../../domain/entities/ai_chat_message.dart';

/// Firestore model for [AiChatMessage]. Persists to and from
/// `aiChats/{coupleId}/messages/{messageId}`.
class AiChatMessageModel extends AiChatMessage {
  const AiChatMessageModel({
    required super.id,
    required super.role,
    required super.text,
    required super.createdAt,
    super.senderUid,
  });

  factory AiChatMessageModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return AiChatMessageModel(
      id: id,
      role: (data['role'] as String?) ?? 'user',
      text: (data['text'] as String?) ?? '',
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      senderUid: data['senderUid'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'role': role,
      'text': text,
      if (senderUid != null) 'senderUid': senderUid,
      'createdAt': createdAt,
    };
  }

  /// Best-effort timestamp parser. Firestore returns a `Timestamp` instance
  /// at runtime; in unit tests / offline mode it may be a Map, a DateTime,
  /// an ISO-8601 String, or null.
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    // Firestore Timestamp (duck-typed to avoid importing cloud_firestore here)
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
      // Treat as milliseconds since epoch.
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
