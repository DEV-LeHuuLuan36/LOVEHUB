import 'package:flutter/foundation.dart';

/// Represents a pending bank-transfer contribution that is waiting for the SePay
/// webhook to confirm the transfer arrived.
@immutable
class PendingContribution {
  const PendingContribution({
    required this.code,
    required this.jarId,
    required this.coupleId,
    required this.byUid,
    required this.byName,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.applied = false,
  });

  /// Unique 8-char transfer reference code, e.g. "LH7K2P9A".
  final String code;

  /// Firestore jar document id.
  final String jarId;

  /// Couple id (for security rules / subcollection path).
  final String coupleId;

  /// Uid of the user who initiated this pending contribution.
  final String byUid;

  /// Display name of the initiator.
  final String byName;

  /// Transfer amount in VND.
  final int amount;

  /// "pending" while waiting; the SePay backend sets it to "confirmed".
  final String status;

  /// When this pending record was created (server timestamp).
  final DateTime createdAt;

  /// True once the Flutter client has applied it to the jar to avoid double-count.
  final bool applied;

  bool get isConfirmed => status == 'confirmed';
  bool get isPending  => status == 'pending';
  bool get isApplied  => applied;

  PendingContribution copyWith({
    String? code,
    String? jarId,
    String? coupleId,
    String? byUid,
    String? byName,
    int? amount,
    String? status,
    DateTime? createdAt,
    bool? applied,
  }) {
    return PendingContribution(
      code: code ?? this.code,
      jarId: jarId ?? this.jarId,
      coupleId: coupleId ?? this.coupleId,
      byUid: byUid ?? this.byUid,
      byName: byName ?? this.byName,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      applied: applied ?? this.applied,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingContribution &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}
