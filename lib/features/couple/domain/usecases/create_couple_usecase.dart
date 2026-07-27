import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/couple.dart';
import '../repositories/couple_repository.dart';

class CreateCoupleUseCase {
  const CreateCoupleUseCase(this._repository);
  final CoupleRepository _repository;

  Future<Either<Failure, Couple>> call(String userId) {
    return _repository.createCouple(userId);
  }
}
