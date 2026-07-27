import 'package:flutter/foundation.dart';

@immutable
class LoveDuration {
  final int days;
  final int hours;
  final int minutes;
  final int seconds;

  const LoveDuration({
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  factory LoveDuration.from(DateTime start, DateTime now) {
    final diff = now.difference(start);
    if (diff.isNegative) {
      return const LoveDuration(days: 0, hours: 0, minutes: 0, seconds: 0);
    }
    final totalSeconds = diff.inSeconds;
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return LoveDuration(days: days, hours: hours, minutes: minutes, seconds: seconds);
  }

  String get hhmmss {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoveDuration &&
          runtimeType == other.runtimeType &&
          days == other.days &&
          hours == other.hours &&
          minutes == other.minutes &&
          seconds == other.seconds;

  @override
  int get hashCode => Object.hash(days, hours, minutes, seconds);
}
