import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../entities/mood_entry.dart';

abstract class MoodRepository {
  Stream<DailyMood> watchTodayMood(String coupleId, String myUid, String partnerUid);

  /// Watches the most recent [days] daily mood docs for this couple
  /// (newest first). Used by the "Last 7 Days" row and the
  /// "Recent Moods" list on the mood screen.
  Stream<List<DailyMood>> watchRecentMoods(
    String coupleId, {
    required String myUid,
    required String partnerUid,
    int days = 14,
  });

  Future<Either<Failure, SetMoodResult>> setMood({
    required String coupleId,
    required String uid,
    required String emoji,
    required String label,
    String? note,
  });
}

@immutable
class SetMoodResult {
  const SetMoodResult({required this.lpAwarded, required this.firstToday});
  final bool lpAwarded;
  final bool firstToday;
}
