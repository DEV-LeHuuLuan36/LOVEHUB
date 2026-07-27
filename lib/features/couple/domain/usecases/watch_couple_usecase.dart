import '../entities/couple.dart';
import '../repositories/couple_repository.dart';

class WatchCoupleUseCase {
  const WatchCoupleUseCase(this._repository);
  final CoupleRepository _repository;

  Stream<Couple?> call(String coupleId) {
    return _repository.watchCouple(coupleId);
  }
}
