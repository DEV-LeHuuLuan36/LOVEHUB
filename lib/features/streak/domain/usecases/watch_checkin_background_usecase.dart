import '../../domain/repositories/checkin_background_repository.dart';

class WatchCheckinBackgroundUseCase {
  WatchCheckinBackgroundUseCase(this._repository);
  final CheckinBackgroundRepository _repository;

  Stream<String?> call(String coupleId) =>
      _repository.watchCheckinBackground(coupleId);
}
