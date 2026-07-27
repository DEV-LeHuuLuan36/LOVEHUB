import 'package:flutter/foundation.dart';

@immutable
class Couple {
  final String id;
  final String code;
  final String user1Id;
  final String? user2Id;
  final String status;
  final DateTime? expiresAt;
  final DateTime? startDate;
  final DateTime? unlinkRequestedAt;
  final String? unlinkRequestedBy;
  final DateTime createdAt;

  const Couple({
    required this.id,
    required this.code,
    required this.user1Id,
    this.user2Id,
    required this.status,
    this.expiresAt,
    this.startDate,
    this.unlinkRequestedAt,
    this.unlinkRequestedBy,
    required this.createdAt,
  });

  bool get isComplete => user2Id != null;

  bool get isPendingUnlink => status == 'pending_unlink';

  DateTime? get unlinkDeadline =>
      unlinkRequestedAt?.add(const Duration(days: 3));

  int get daysLeftToRecover {
    final deadline = unlinkDeadline;
    if (deadline == null) return 0;
    final diff = deadline.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  Couple copyWith({
    String? id,
    String? code,
    String? user1Id,
    String? user2Id,
    String? status,
    DateTime? expiresAt,
    DateTime? startDate,
    DateTime? unlinkRequestedAt,
    String? unlinkRequestedBy,
    DateTime? createdAt,
  }) {
    return Couple(
      id: id ?? this.id,
      code: code ?? this.code,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      startDate: startDate ?? this.startDate,
      unlinkRequestedAt: unlinkRequestedAt ?? this.unlinkRequestedAt,
      unlinkRequestedBy: unlinkRequestedBy ?? this.unlinkRequestedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Couple &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          user1Id == other.user1Id &&
          user2Id == other.user2Id &&
          status == other.status;

  @override
  int get hashCode =>
      id.hashCode ^
      code.hashCode ^
      user1Id.hashCode ^
      user2Id.hashCode ^
      status.hashCode;
}
