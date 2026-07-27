import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/mood_entry.dart';

class MoodEntryModel extends MoodEntry {
  const MoodEntryModel({
    required super.uid,
    required super.emoji,
    required super.label,
    super.note,
    required super.updatedAt,
  });

  factory MoodEntryModel.fromFirestore(String uid, Map<String, dynamic> data) {
    return MoodEntryModel(
      uid: uid,
      emoji: (data['emoji'] as String?) ?? '',
      label: (data['label'] as String?) ?? '',
      note: data['note'] as String?,
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is Map) {
      // Some test/seeding paths hand us a plain `{_seconds, _nanoseconds}`
      // map instead of a real Timestamp.
      final seconds = value['_seconds'];
      if (seconds is int) {
        final nanos = (value['_nanoseconds'] as int?) ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanos ~/ 1000000),
        );
      }
    }
    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'emoji': emoji,
      'label': label,
      'note': note,
      'updatedAt': updatedAt,
    };
  }
}
