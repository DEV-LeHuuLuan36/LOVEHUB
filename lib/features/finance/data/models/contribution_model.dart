import '../../domain/entities/contribution.dart';

class ContributionModel extends Contribution {
  const ContributionModel({
    required super.id,
    required super.coupleId,
    required super.jarId,
    required super.userId,
    required super.userName,
    required super.amount,
    super.note,
    required super.method,
    required super.source,
    required super.createdAt,
  });

  factory ContributionModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return ContributionModel(
      id: id,
      coupleId: data['coupleId'] as String? ?? '',
      jarId: data['jarId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      note: data['note'] as String?,
      method: data['method'] as String? ?? 'manual',
      source: data['source'] as String? ?? 'manual',
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is DateTime) return value;
    if (value is Map) {
      final millis = value['_seconds'] as int?;
      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis * 1000);
      }
    }
    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'coupleId': coupleId,
      'jarId': jarId,
      'userId': userId,
      'userName': userName,
      'amount': amount,
      'note': note,
      'method': method,
      'source': source,
      'createdAt': createdAt,
    };
  }
}
