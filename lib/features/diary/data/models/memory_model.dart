import '../../domain/entities/memory.dart';

class MemoryModel extends Memory {
  const MemoryModel({
    required super.id,
    required super.coupleId,
    required super.title,
    super.story,
    required super.category,
    required super.date,
    required super.photoUrls,
    super.mood,
    required super.authorUid,
    required super.createdAt,
  });

  factory MemoryModel.fromFirestore(String id, Map<String, dynamic> data) {
    return MemoryModel(
      id: id,
      coupleId: data['coupleId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      story: data['story'] as String?,
      category: data['category'] as String? ?? 'other',
      date: _parseTimestamp(data['date']),
      photoUrls: (data['photoUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      mood: data['mood'] as String?,
      authorUid: data['authorUid'] as String? ?? '',
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
      'title': title,
      'story': story,
      'category': category,
      'date': date,
      'photoUrls': photoUrls,
      'mood': mood,
      'authorUid': authorUid,
      'createdAt': createdAt,
    };
  }

  @override
  MemoryModel copyWith({
    String? id,
    String? coupleId,
    String? title,
    String? story,
    String? category,
    DateTime? date,
    List<String>? photoUrls,
    String? mood,
    String? authorUid,
    DateTime? createdAt,
  }) {
    return MemoryModel(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      title: title ?? this.title,
      story: story ?? this.story,
      category: category ?? this.category,
      date: date ?? this.date,
      photoUrls: photoUrls ?? this.photoUrls,
      mood: mood ?? this.mood,
      authorUid: authorUid ?? this.authorUid,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
