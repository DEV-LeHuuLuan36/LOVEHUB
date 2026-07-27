import '../../domain/entities/saving_jar.dart';

class SavingJarModel extends SavingJar {
  const SavingJarModel({
    required super.id,
    required super.coupleId,
    required super.name,
    required super.emoji,
    required super.targetAmount,
    required super.currentAmount,
    super.deadline,
    required super.createdAt,
    super.bankCode,
    super.bankAccountNumber,
    super.bankAccountName,
  });

  factory SavingJarModel.fromFirestore(String id, Map<String, dynamic> data) {
    return SavingJarModel(
      id: id,
      coupleId: data['coupleId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      emoji: data['emoji'] as String? ?? '🐷',
      targetAmount: (data['targetAmount'] as num?)?.toInt() ?? 0,
      currentAmount: (data['currentAmount'] as num?)?.toInt() ?? 0,
      deadline: _parseTimestamp(data['deadline']),
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      bankCode: data['bankCode'] as String?,
      bankAccountNumber: data['bankAccountNumber'] as String?,
      bankAccountName: data['bankAccountName'] as String?,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Map) {
      final millis = value['_seconds'] as int?;
      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis * 1000);
      }
    }
    return null;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'coupleId': coupleId,
      'name': name,
      'emoji': emoji,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'deadline': deadline,
      'createdAt': createdAt,
      if (bankCode != null && bankCode!.isNotEmpty) 'bankCode': bankCode,
      if (bankAccountNumber != null && bankAccountNumber!.isNotEmpty)
        'bankAccountNumber': bankAccountNumber,
      if (bankAccountName != null && bankAccountName!.isNotEmpty)
        'bankAccountName': bankAccountName,
    };
  }
}
