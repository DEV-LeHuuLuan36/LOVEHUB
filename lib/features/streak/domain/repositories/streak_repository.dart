import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/streak_entity.dart';

abstract class StreakRepository {
  Stream<StreakEntity> watchStreak({
    required String coupleId,
    required String myUid,
    required String partnerId,
  });

  Future<Either<Failure, StreakEntity>> checkIn({
    required String coupleId,
    required String myUid,
    required String partnerId,
  });

  Future<Either<Failure, StreakEntity>> useRecoveryToken({
    required String coupleId,
    required String myUid,
    required String partnerId,
  });
}
