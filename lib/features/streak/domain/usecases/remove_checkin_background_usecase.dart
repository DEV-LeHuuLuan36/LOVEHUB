import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/checkin_background_repository.dart';

class RemoveCheckinBackgroundUseCase {
  RemoveCheckinBackgroundUseCase(this._repository);
  final CheckinBackgroundRepository _repository;

  Future<Either<Failure, Unit>> call(String coupleId) =>
      _repository.removeCheckinBackground(coupleId);
}
