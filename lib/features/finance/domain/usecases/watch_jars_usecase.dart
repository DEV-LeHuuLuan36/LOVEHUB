import '../entities/saving_jar.dart';
import '../repositories/finance_repository.dart';

class WatchJarsUseCase {
  WatchJarsUseCase(this._repository);
  final FinanceRepository _repository;

  Stream<List<SavingJar>> call(String coupleId) {
    return _repository.watchJars(coupleId);
  }
}
