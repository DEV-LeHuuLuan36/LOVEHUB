import 'package:flutter/foundation.dart';

@immutable
class MoodOption {
  const MoodOption({required this.emoji, required this.label});

  final String emoji;
  final String label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodOption &&
          runtimeType == other.runtimeType &&
          emoji == other.emoji &&
          label == other.label;

  @override
  int get hashCode => emoji.hashCode ^ label.hashCode;
}

const List<MoodOption> moodOptions = [
  MoodOption(emoji: '😊', label: 'Happy'),
  MoodOption(emoji: '🥰', label: 'In Love'),
  MoodOption(emoji: '😐', label: 'Okay'),
  MoodOption(emoji: '😔', label: 'Sad'),
  MoodOption(emoji: '😡', label: 'Upset'),
];
