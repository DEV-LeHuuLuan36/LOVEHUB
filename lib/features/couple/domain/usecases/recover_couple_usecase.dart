import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/couple_repository.dart';

class RecoverCoupleUseCase {
  const RecoverCoupleUseCase(this._repository);
  final CoupleRepository _repository;

  Future<Either<Failure, Unit>> call(String coupleId) {
    return _repository.recoverCouple(coupleId);
  }
}
