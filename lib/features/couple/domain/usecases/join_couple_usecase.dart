import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/couple.dart';
import '../repositories/couple_repository.dart';

class JoinCoupleUseCase {
  const JoinCoupleUseCase(this._repository);
  final CoupleRepository _repository;

  Future<Either<Failure, Couple>> call({required String userId, required String code}) {
    return _repository.joinCouple(userId, code);
  }
}
