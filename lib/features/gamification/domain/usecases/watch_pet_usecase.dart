import '../../domain/entities/pet_entity.dart';
import '../../domain/repositories/pet_repository.dart';

class WatchPetUseCase {
  WatchPetUseCase(this._repository);

  final PetRepository _repository;

  Stream<PetEntity> call(String coupleId) {
    return _repository.watchPet(coupleId);
  }
}
