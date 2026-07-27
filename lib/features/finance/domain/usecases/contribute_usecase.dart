import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/finance_repository.dart';

class ContributeUseCase {
  ContributeUseCase(this._repository);
  final FinanceRepository _repository;

  Future<Either<Failure, Unit>> call({
    required String coupleId,
    required String jarId,
    required String userId,
    required String userName,
    required int amount,
    String? note,
    required String method,
  }) {
    return _repository.contribute(
      coupleId: coupleId,
      jarId: jarId,
      userId: userId,
      userName: userName,
      amount: amount,
      note: note,
      method: method,
    );
  }
}
