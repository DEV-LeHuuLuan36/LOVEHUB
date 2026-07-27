import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/finance_repository.dart';

class CreateJarUseCase {
  CreateJarUseCase(this._repository);
  final FinanceRepository _repository;

  Future<Either<Failure, Unit>> call({
    required String coupleId,
    required String name,
    required String emoji,
    required int targetAmount,
    DateTime? deadline,
    int initialDeposit = 0,
    String? bankCode,
    String? bankAccountNumber,
    String? bankAccountName,
  }) {
    return _repository.createJar(
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
  }
}
