import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/streak_entity.dart';
import '../../domain/repositories/streak_repository.dart';
import '../datasources/streak_remote_datasource.dart';

class StreakRepositoryImpl implements StreakRepository {
  StreakRepositoryImpl({required StreakRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final StreakRemoteDataSource _remoteDataSource;

  @override
  Stream<StreakEntity> watchStreak({
    required String coupleId,
    required String myUid,
    required String partnerId,
  }) {
    return _remoteDataSource.watchStreak(
      coupleId: coupleId,
      myUid: myUid,
      partnerId: partnerId,
    );
  }

  @override
  Future<Either<Failure, StreakEntity>> checkIn({
    required String coupleId,
    required String myUid,
    required String partnerId,
  }) async {
    try {
      final result = await _remoteDataSource.checkIn(
        coupleId: coupleId,
        myUid: myUid,
        partnerId: partnerId,
      );
      debugPrint('CHECKIN_DBG: repo.checkIn OK');
      return Right(result);
    } on FirebaseException catch (e) {
      debugPrint(
        'CHECKIN_DBG_ERR: FirebaseException code=${e.code}, '
        'message=${e.message}',
      );
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } on StreakException catch (e) {
      debugPrint('CHECKIN_DBG_ERR: StreakException ${e.message}');
      return Left(ServerFailure(e.message));
    } catch (e, st) {
      debugPrint('CHECKIN_DBG_ERR: unexpected $e\n$st');
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, StreakEntity>> useRecoveryToken({
    required String coupleId,
    required String myUid,
    required String partnerId,
  }) async {
    try {
      final result = await _remoteDataSource.useRecoveryToken(
        coupleId: coupleId,
        myUid: myUid,
        partnerId: partnerId,
      );
      return Right(result);
    } on StreakException catch (e) {
      return Left(ServerFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
