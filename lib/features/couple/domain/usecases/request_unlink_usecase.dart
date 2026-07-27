import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/couple_repository.dart';

class RequestUnlinkUseCase {
  const RequestUnlinkUseCase(this._repository);
  final CoupleRepository _repository;

  Future<Either<Failure, Unit>> call({required String coupleId, required String userId}) {
    return _repository.requestUnlink(coupleId, userId);
  }
}
