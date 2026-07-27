import '../entities/contribution.dart';
import '../repositories/finance_repository.dart';

class WatchContributionsUseCase {
  WatchContributionsUseCase(this._repository);
  final FinanceRepository _repository;

  Stream<List<Contribution>> call(String coupleId, String jarId) {
    return _repository.watchContributions(coupleId, jarId);
  }
}
