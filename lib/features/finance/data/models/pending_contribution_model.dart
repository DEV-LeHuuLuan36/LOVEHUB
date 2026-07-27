import '../../domain/entities/pending_contribution.dart';

class PendingContributionModel extends PendingContribution {
  const PendingContributionModel({
    required super.code,
    required super.jarId,
    required super.coupleId,
    required super.byUid,
    required super.byName,
    required super.amount,
    required super.status,
    required super.createdAt,
    super.applied,
  });

  factory PendingContributionModel.fromFirestore(
    String code,
    Map<String, dynamic> data,
  ) {
    return PendingContributionModel(
      code: code,
      jarId: data['jarId'] as String? ?? '',
      coupleId: data['coupleId'] as String? ?? '',
      byUid: data['byUid'] as String? ?? '',
      byName: data['byName'] as String? ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'pending',
      createdAt: _parseTimestamp(data['createdAt']),
      applied: data['applied'] as bool? ?? false,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is DateTime) return value;
    if (value is Map) {
      final millis = (value['_seconds'] as int?) ?? (value['seconds'] as int?);
      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis * 1000);
      }
    }
    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'jarId': jarId,
      'coupleId': coupleId,
      'byUid': byUid,
      'byName': byName,
      'amount': amount,
      'status': status,
      'createdAt': createdAt,
      'applied': applied,
    };
  }

  @override
  PendingContributionModel copyWith({
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
    return PendingContributionModel(
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
}
