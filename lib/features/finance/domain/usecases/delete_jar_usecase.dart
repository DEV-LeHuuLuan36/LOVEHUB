import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/finance_repository.dart';

class DeleteJarUseCase {
  DeleteJarUseCase(this._repository);
  final FinanceRepository _repository;

  Future<Either<Failure, Unit>> call({
    required String coupleId,
    required String jarId,
  }) {
    return _repository.deleteJar(
      coupleId: coupleId,
      jarId: jarId,
    );
  }
}
