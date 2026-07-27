import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/couple.dart';

class CoupleModel extends Couple {
  const CoupleModel({
    required super.id,
    required super.code,
    required super.user1Id,
    super.user2Id,
    required super.status,
    super.expiresAt,
    super.startDate,
    super.unlinkRequestedAt,
    super.unlinkRequestedBy,
    required super.createdAt,
  });

  factory CoupleModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CoupleModel(
      id: doc.id,
      code: data['code'] as String? ?? '',
      user1Id: data['user1Id'] as String? ?? '',
      user2Id: data['user2Id'] as String?,
      status: data['status'] as String? ?? 'waiting',
      expiresAt: _toDateTime(data['expiresAt']),
      startDate: _toDateTime(data['startDate']),
      unlinkRequestedAt: _toDateTime(data['unlinkRequestedAt']),
      unlinkRequestedBy: data['unlinkRequestedBy'] as String?,
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'user1Id': user1Id,
      if (user2Id != null) 'user2Id': user2Id,
      'status': status,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
      if (createdAt != DateTime(0)) 'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
