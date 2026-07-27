import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/pat_result.dart';
import '../../domain/entities/pet_entity.dart';
import '../../domain/repositories/pet_repository.dart';
import '../datasources/pet_remote_datasource.dart';

class PetRepositoryImpl implements PetRepository {
  PetRepositoryImpl({required PetRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final PetRemoteDataSource _remoteDataSource;

  @override
  Stream<PetEntity> watchPet(String coupleId) {
    return _remoteDataSource.watchPet(coupleId);
  }

  @override
  Future<Either<Failure, PetEntity>> feed(String coupleId) async {
    try {
      final result = await _remoteDataSource.feed(coupleId);
      return Right(result);
    } on PetException catch (e) {
      return Left(ServerFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PatResult>> pat(String coupleId) async {
    try {
      final result = await _remoteDataSource.pat(coupleId);
      return Right(result);
    } on PetException catch (e) {
      return Left(ServerFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addLovePoints(String coupleId, int amount) async {
    try {
      await _remoteDataSource.addLovePoints(coupleId, amount);
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addFood(String coupleId, int amount) async {
    try {
      await _remoteDataSource.addFood(coupleId, amount);
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setPetType(String coupleId, PetType type) async {
    try {
      await _remoteDataSource.setPetType(coupleId, type);
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
