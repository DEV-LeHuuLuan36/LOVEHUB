import '../../domain/entities/mood_entry.dart';
import '../../domain/repositories/mood_repository.dart';

class WatchTodayMoodUseCase {
  WatchTodayMoodUseCase(this._repository);
  final MoodRepository _repository;

  Stream<DailyMood> call(String coupleId, String myUid, String partnerUid) {
    return _repository.watchTodayMood(coupleId, myUid, partnerUid);
  }
}
