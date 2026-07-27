import 'package:flutter/foundation.dart';

@immutable
class Contribution {
  const Contribution({
    required this.id,
    required this.coupleId,
    required this.jarId,
    required this.userId,
    required this.userName,
    required this.amount,
    this.note,
    required this.method, // 'qr' | 'manual'
    required this.source,
    required this.createdAt,
  });

  final String id;
  final String coupleId;
  final String jarId;
  final String userId;
  final String userName;
  final int amount;
  final String? note;
  final String method; // 'qr' | 'manual'
  final String source;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Contribution &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          coupleId == other.coupleId &&
          jarId == other.jarId &&
          userId == other.userId &&
          userName == other.userName &&
          amount == other.amount &&
          note == other.note &&
          method == other.method &&
          source == other.source &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      coupleId.hashCode ^
      jarId.hashCode ^
      userId.hashCode ^
      userName.hashCode ^
      amount.hashCode ^
      note.hashCode ^
      method.hashCode ^
      source.hashCode ^
      createdAt.hashCode;
}
