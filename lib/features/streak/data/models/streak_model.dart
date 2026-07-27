import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/streak_entity.dart';

class StreakModel extends StreakEntity {
  const StreakModel({
    required super.currentStreak,
    super.lastCompleteDate,
    required super.meCheckedToday,
    required super.partnerCheckedToday,
    required super.partnerId,
    super.recoveryTokens,
    super.streakBeforeBreak,
    super.brokenAt,
    super.checkins,
  });

  factory StreakModel.fromFirestore(Map<String, dynamic> data, String myUid, String partnerId) {
    final rawCheckins = data['checkins'] as Map<String, dynamic>? ?? {};
    final today = StreakEntity.todayStr();
    final todayCheckins = rawCheckins[today] as Map<String, dynamic>? ?? {};

    // Build the full per-day → uids map for calendar/grid rendering.
    // The map may contain dates that aren't today/yesterday; we keep
    // them all so the history screen can render any range.
    final checkins = <String, Set<String>>{};
    rawCheckins.forEach((date, value) {
      if (value is Map) {
        checkins[date] = value.keys
            .where((k) => value[k] == true)
            .map((k) => k.toString())
            .toSet();
      }
    });

    DateTime? parsedBrokenAt;
    final rawBrokenAt = data['brokenAt'];
    if (rawBrokenAt is Timestamp) {
      parsedBrokenAt = rawBrokenAt.toDate();
    } else if (rawBrokenAt is Map) {
      parsedBrokenAt = (rawBrokenAt['_seconds'] as int?) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (rawBrokenAt['_seconds'] as int) * 1000 +
                  ((rawBrokenAt['_nanoseconds'] as int?) ?? 0) ~/ 1000000)
          : null;
    }

    return StreakModel(
      currentStreak: (data['currentStreak'] as int?) ?? 0,
      lastCompleteDate: data['lastCompleteDate'] as String?,
      meCheckedToday: todayCheckins.containsKey(myUid),
      partnerCheckedToday: todayCheckins.containsKey(partnerId),
      partnerId: partnerId,
      recoveryTokens: (data['recoveryTokens'] as int?) ?? 0,
      streakBeforeBreak: (data['streakBeforeBreak'] as int?) ?? 0,
      brokenAt: parsedBrokenAt,
      checkins: checkins,
    );
  }

  static StreakModel empty(String partnerId) {
    return StreakModel(
      currentStreak: 0,
      lastCompleteDate: null,
      meCheckedToday: false,
      partnerCheckedToday: false,
      partnerId: partnerId,
      recoveryTokens: 0,
      streakBeforeBreak: 0,
      brokenAt: null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'currentStreak': currentStreak,
      'lastCompleteDate': lastCompleteDate,
      'recoveryTokens': recoveryTokens,
      'streakBeforeBreak': streakBeforeBreak,
      'brokenAt': brokenAt != null ? Timestamp.fromDate(brokenAt!) : null,
    };
  }

  StreakModel copyWith({
    int? currentStreak,
    String? lastCompleteDate,
    bool? meCheckedToday,
    bool? partnerCheckedToday,
    String? partnerId,
    int? recoveryTokens,
    int? streakBeforeBreak,
    DateTime? brokenAt,
    Map<String, Set<String>>? checkins,
  }) {
    return StreakModel(
      currentStreak: currentStreak ?? this.currentStreak,
      lastCompleteDate: lastCompleteDate ?? this.lastCompleteDate,
      meCheckedToday: meCheckedToday ?? this.meCheckedToday,
      partnerCheckedToday: partnerCheckedToday ?? this.partnerCheckedToday,
      partnerId: partnerId ?? this.partnerId,
      recoveryTokens: recoveryTokens ?? this.recoveryTokens,
      streakBeforeBreak: streakBeforeBreak ?? this.streakBeforeBreak,
      brokenAt: brokenAt ?? this.brokenAt,
      checkins: checkins ?? this.checkins,
    );
  }
}
