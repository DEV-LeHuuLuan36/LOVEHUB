import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/couple.dart';

abstract class CoupleRepository {
  Future<Either<Failure, Couple>> createCouple(String userId);
  Future<Either<Failure, Couple>> joinCouple(String userId, String code);
  Future<Either<Failure, Unit>> updateStartDate(String coupleId, DateTime date);
  Future<Either<Failure, Unit>> requestUnlink(String coupleId, String userId);
  Future<Either<Failure, Unit>> recoverCouple(String coupleId);
  Future<Either<Failure, Unit>> finalizeUnlinkIfExpired(String coupleId);
  Stream<Couple?> watchCouple(String coupleId);
}
