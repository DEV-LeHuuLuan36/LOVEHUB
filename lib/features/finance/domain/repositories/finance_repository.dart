import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/contribution.dart';
import '../entities/saving_jar.dart';

abstract class FinanceRepository {
  Stream<List<SavingJar>> watchJars(String coupleId);
  Stream<List<Contribution>> watchContributions(String coupleId, String jarId);

  Future<Either<Failure, Unit>> createJar({
    required String coupleId,
    required String name,
    required String emoji,
    required int targetAmount,
    DateTime? deadline,
    int initialDeposit,
    String? bankCode,
    String? bankAccountNumber,
    String? bankAccountName,
  });

  Future<Either<Failure, Unit>> contribute({
    required String coupleId,
    required String jarId,
    required String userId,
    required String userName,
    required int amount,
    String? note,
    required String method,
  });

  Future<Either<Failure, Unit>> deleteJar({
    required String coupleId,
    required String jarId,
  });
}
