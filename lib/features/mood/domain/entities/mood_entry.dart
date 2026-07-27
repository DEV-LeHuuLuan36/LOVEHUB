import 'package:flutter/foundation.dart';

@immutable
class MoodEntry {
  final String uid;
  final String emoji;
  final String label;
  final String? note;
  final DateTime updatedAt;

  const MoodEntry({
    required this.uid,
    required this.emoji,
    required this.label,
    this.note,
    required this.updatedAt,
  });

  bool get isPositive => label == 'Happy' || label == 'In Love';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodEntry &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          emoji == other.emoji &&
          label == other.label &&
          note == other.note;

  @override
  int get hashCode => uid.hashCode ^ emoji.hashCode ^ label.hashCode ^ note.hashCode;
}

@immutable
class DailyMood {
  final String date;
  final MoodEntry? mine;
  final MoodEntry? partner;

  const DailyMood({
    required this.date,
    this.mine,
    this.partner,
  });

  bool get bothPositive => mine?.isPositive == true && partner?.isPositive == true;
  bool get mineSet => mine != null;
  bool get partnerSet => partner != null;
}
