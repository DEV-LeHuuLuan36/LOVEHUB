import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/pet_entity.dart';
import '../../domain/repositories/pet_repository.dart';

class FeedPetUseCase {
  FeedPetUseCase(this._repository);

  final PetRepository _repository;

  Future<Either<Failure, PetEntity>> call(String coupleId) {
    return _repository.feed(coupleId);
  }
}
