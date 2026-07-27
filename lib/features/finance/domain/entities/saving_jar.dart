import 'package:flutter/foundation.dart';

@immutable
class SavingJar {
  const SavingJar({
    required this.id,
    required this.coupleId,
    required this.name,
    required this.emoji,
    required this.targetAmount,
    required this.currentAmount,
    this.deadline,
    required this.createdAt,
    this.bankCode,
    this.bankAccountNumber,
    this.bankAccountName,
  });

  final String id;
  final String coupleId;
  final String name;
  final String emoji;
  final int targetAmount;
  final int currentAmount;
  final DateTime? deadline;
  final DateTime createdAt;
  final String? bankCode;
  final String? bankAccountNumber;
  final String? bankAccountName;

  bool get hasBankInfo =>
      bankCode != null &&
      bankCode!.isNotEmpty &&
      bankAccountNumber != null &&
      bankAccountNumber!.isNotEmpty;

  double get progress {
    if (targetAmount <= 0) return 0;
    final raw = currentAmount / targetAmount;
    if (raw.isNaN || raw.isInfinite) return 0;
    return raw.clamp(0.0, 1.0);
  }

  int get percentInt => (progress * 100).round();

  /// Rounded integer for values >= 1%; one-decimal string for tiny fractions.
  /// This ensures that 5,000 / 5,000,000 (0.1%) shows "0.1%" instead of "0%".
  String get percentFormatted {
    final pct = progress * 100;
    if (pct < 1.0 && pct > 0) {
      return '${pct.toStringAsFixed(1)}%';
    }
    return '${pct.round()}%';
  }

  SavingJar copyWith({
    String? id,
    String? coupleId,
    String? name,
    String? emoji,
    int? targetAmount,
    int? currentAmount,
    DateTime? deadline,
    DateTime? createdAt,
    String? bankCode,
    String? bankAccountNumber,
    String? bankAccountName,
  }) {
    return SavingJar(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      bankCode: bankCode ?? this.bankCode,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountName: bankAccountName ?? this.bankAccountName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavingJar &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          coupleId == other.coupleId &&
          name == other.name &&
          emoji == other.emoji &&
          targetAmount == other.targetAmount &&
          currentAmount == other.currentAmount &&
          deadline == other.deadline &&
          createdAt == other.createdAt &&
          bankCode == other.bankCode &&
          bankAccountNumber == other.bankAccountNumber &&
          bankAccountName == other.bankAccountName;

  @override
  int get hashCode =>
      id.hashCode ^
      coupleId.hashCode ^
      name.hashCode ^
      emoji.hashCode ^
      targetAmount.hashCode ^
      currentAmount.hashCode ^
      deadline.hashCode ^
      createdAt.hashCode ^
      bankCode.hashCode ^
      bankAccountNumber.hashCode ^
      bankAccountName.hashCode;
}
