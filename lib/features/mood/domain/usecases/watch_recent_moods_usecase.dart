import '../../domain/entities/mood_entry.dart';
import '../../domain/repositories/mood_repository.dart';

/// Streams the most recent N daily mood docs for a couple
/// (newest first). Each item is a [DailyMood] with optional
/// `mine` and `partner` entries.
class WatchRecentMoodsUseCase {
  WatchRecentMoodsUseCase(this._repository);
  final MoodRepository _repository;

  Stream<List<DailyMood>> call(
    String coupleId, {
    required String myUid,
    required String partnerUid,
    int days = 14,
  }) {
    return _repository.watchRecentMoods(
      coupleId,
      myUid: myUid,
      partnerUid: partnerUid,
      days: days,
    );
  }
}
