import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/couple_repository.dart';

class FinalizeUnlinkUseCase {
  const FinalizeUnlinkUseCase(this._repository);
  final CoupleRepository _repository;

  Future<Either<Failure, Unit>> call(String coupleId) {
    return _repository.finalizeUnlinkIfExpired(coupleId);
  }
}
