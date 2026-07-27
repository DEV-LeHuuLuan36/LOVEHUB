import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/couple.dart';
import '../../domain/repositories/couple_repository.dart';
import '../datasources/couple_remote_datasource.dart';

class CoupleRepositoryImpl implements CoupleRepository {
  CoupleRepositoryImpl({required CoupleRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final CoupleRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, Couple>> createCouple(String userId) async {
    try {
      final couple = await _remoteDataSource.createCouple(userId);
      return Right(couple);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Couple>> joinCouple(String userId, String code) async {
    try {
      final couple = await _remoteDataSource.joinCouple(userId, code);
      return Right(couple);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateStartDate(String coupleId, DateTime date) async {
    try {
      await _remoteDataSource.updateStartDate(coupleId, date);
      return const Right(unit);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> requestUnlink(String coupleId, String userId) async {
    try {
      await _remoteDataSource.requestUnlink(coupleId, userId);
      return const Right(unit);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> recoverCouple(String coupleId) async {
    try {
      await _remoteDataSource.recoverCouple(coupleId);
      return const Right(unit);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> finalizeUnlinkIfExpired(String coupleId) async {
    try {
      await _remoteDataSource.finalizeUnlinkIfExpired(coupleId);
      return const Right(unit);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Stream<Couple?> watchCouple(String coupleId) {
    return _remoteDataSource.watchCouple(coupleId);
  }
}
