import '../../domain/entities/streak_entity.dart';
import '../../domain/repositories/streak_repository.dart';

class WatchStreakUseCase {
  WatchStreakUseCase(this._repository);

  final StreakRepository _repository;

  Stream<StreakEntity> call({
    required String coupleId,
    required String myUid,
    required String partnerId,
  }) {
    return _repository.watchStreak(
      coupleId: coupleId,
      myUid: myUid,
      partnerId: partnerId,
    );
  }
}
