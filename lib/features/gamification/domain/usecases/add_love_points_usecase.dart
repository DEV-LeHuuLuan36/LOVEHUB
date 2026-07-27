import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/pet_repository.dart';

class AddLovePointsUseCase {
  AddLovePointsUseCase(this._repository);

  final PetRepository _repository;

  Future<Either<Failure, void>> call(String coupleId, int amount) {
    return _repository.addLovePoints(coupleId, amount);
  }
}
