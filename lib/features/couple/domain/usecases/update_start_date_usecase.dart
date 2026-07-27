import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/couple_repository.dart';

class UpdateStartDateUseCase {
  const UpdateStartDateUseCase(this._repository);
  final CoupleRepository _repository;

  Future<Either<Failure, Unit>> call({required String coupleId, required DateTime date}) {
    return _repository.updateStartDate(coupleId, date);
  }
}
