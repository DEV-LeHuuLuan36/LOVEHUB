import 'package:flutter/foundation.dart';

enum StreakStatus {
  active,
  atRisk,
  broken,
  idle,
}

@immutable
class StreakEntity {
  final int currentStreak;
  final String? lastCompleteDate;
  final bool meCheckedToday;
  final bool partnerCheckedToday;
  final String partnerId;
  final int recoveryTokens;
  final int streakBeforeBreak;
  final DateTime? brokenAt;

  /// Raw check-ins keyed by `yyyy-MM-dd`, value is the set of uids
  /// (from this couple) that checked in on that day. Used by the
  /// 7-day row on the streak screen and the monthly grid on the
  /// history screen — it lets the UI render "Both / One / Missed"
  /// per day without a second Firestore query.
  final Map<String, Set<String>> checkins;

  const StreakEntity({
    required this.currentStreak,
    this.lastCompleteDate,
    required this.meCheckedToday,
    required this.partnerCheckedToday,
    required this.partnerId,
    this.recoveryTokens = 0,
    this.streakBeforeBreak = 0,
    this.brokenAt,
    this.checkins = const <String, Set<String>>{},
  });

  bool get bothCheckedToday => meCheckedToday && partnerCheckedToday;
  bool get neitherCheckedToday => !meCheckedToday && !partnerCheckedToday;

  StreakStatus get status {
    if (currentStreak == 0 && lastCompleteDate == null) {
      return StreakStatus.idle;
    }
    if (_isBroken) return StreakStatus.broken;
    if (bothCheckedToday) return StreakStatus.active;
    if (!meCheckedToday && !partnerCheckedToday) return StreakStatus.idle;
    return StreakStatus.atRisk;
  }

  /// True if the streak is broken and a recovery token can be used right now.
  bool get canRecover {
    if (status != StreakStatus.broken) return false;
    if (recoveryTokens <= 0) return false;
    if (brokenAt == null) return false;
    final elapsed = DateTime.now().difference(brokenAt!);
    return elapsed.inHours <= 48;
  }

  bool get _isBroken {
    if (lastCompleteDate == null) return false;
    final today = _todayStr();
    final yesterday = _dateStr(DateTime.now().subtract(const Duration(days: 1)));
    return lastCompleteDate != today && lastCompleteDate != yesterday;
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _dateStr(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String todayStr() => _todayStr();

  static String yesterdayStr() => _dateStr(DateTime.now().subtract(const Duration(days: 1)));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakEntity &&
          runtimeType == other.runtimeType &&
          currentStreak == other.currentStreak &&
          lastCompleteDate == other.lastCompleteDate &&
          meCheckedToday == other.meCheckedToday &&
          partnerCheckedToday == other.partnerCheckedToday &&
          recoveryTokens == other.recoveryTokens &&
          brokenAt == other.brokenAt;

  @override
  int get hashCode =>
      currentStreak.hashCode ^
      lastCompleteDate.hashCode ^
      meCheckedToday.hashCode ^
      partnerCheckedToday.hashCode ^
      recoveryTokens.hashCode ^
      brokenAt.hashCode;
}
