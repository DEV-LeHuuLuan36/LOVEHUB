import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/pat_result.dart';
import '../entities/pet_entity.dart';

abstract class PetRepository {
  Stream<PetEntity> watchPet(String coupleId);

  Future<Either<Failure, PetEntity>> feed(String coupleId);

  Future<Either<Failure, PatResult>> pat(String coupleId);

  Future<Either<Failure, void>> addLovePoints(String coupleId, int amount);

  Future<Either<Failure, void>> addFood(String coupleId, int amount);

  Future<Either<Failure, void>> setPetType(String coupleId, PetType type);
}
