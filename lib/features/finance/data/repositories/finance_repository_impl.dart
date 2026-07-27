import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/contribution.dart';
import '../../domain/entities/saving_jar.dart';
import '../../domain/repositories/finance_repository.dart';
import '../datasources/finance_remote_datasource.dart';

class FinanceRepositoryImpl implements FinanceRepository {
  FinanceRepositoryImpl({required FinanceRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final FinanceRemoteDataSource _remoteDataSource;

  @override
  Stream<List<SavingJar>> watchJars(String coupleId) {
    return _remoteDataSource.watchJars(coupleId);
  }

  @override
  Stream<List<Contribution>> watchContributions(
    String coupleId,
    String jarId,
  ) {
    return _remoteDataSource.watchContributions(coupleId, jarId);
  }

  @override
  Future<Either<Failure, Unit>> createJar({
    required String coupleId,
    required String name,
    required String emoji,
    required int targetAmount,
    DateTime? deadline,
    int initialDeposit = 0,
    String? bankCode,
    String? bankAccountNumber,
    String? bankAccountName,
  }) async {
    try {
      await _remoteDataSource.createJar(
        coupleId: coupleId,
        name: name,
        emoji: emoji,
        targetAmount: targetAmount,
        deadline: deadline,
        initialDeposit: initialDeposit,
        bankCode: bankCode,
        bankAccountNumber: bankAccountNumber,
        bankAccountName: bankAccountName,
      );
      return const Right(unit);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> contribute({
    required String coupleId,
    required String jarId,
    required String userId,
    required String userName,
    required int amount,
    String? note,
    required String method,
  }) async {
    try {
      await _remoteDataSource.contribute(
        coupleId: coupleId,
        jarId: jarId,
        userId: userId,
        userName: userName,
        amount: amount,
        note: note,
        method: method,
      );
      return const Right(unit);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteJar({
    required String coupleId,
    required String jarId,
  }) async {
    try {
      await _remoteDataSource.deleteJar(
        coupleId: coupleId,
        jarId: jarId,
      );
      return const Right(unit);
    } on FirebaseException catch (e) {
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
