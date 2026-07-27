import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/streak_entity.dart';
import '../../domain/repositories/streak_repository.dart';

class CheckInUseCase {
  CheckInUseCase(this._repository);

  final StreakRepository _repository;

  Future<Either<Failure, StreakEntity>> call({
    required String coupleId,
    required String myUid,
    required String partnerId,
  }) {
    return _repository.checkIn(
      coupleId: coupleId,
      myUid: myUid,
      partnerId: partnerId,
    );
  }
}
