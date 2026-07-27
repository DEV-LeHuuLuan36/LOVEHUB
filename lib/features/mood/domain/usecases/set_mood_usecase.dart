import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/mood_repository.dart';

class SetMoodUseCase {
  SetMoodUseCase(this._repository);
  final MoodRepository _repository;

  Future<Either<Failure, SetMoodResult>> call({
    required String coupleId,
    required String uid,
    required String emoji,
    required String label,
    String? note,
  }) {
    return _repository.setMood(
      coupleId: coupleId,
      uid: uid,
      emoji: emoji,
      label: label,
      note: note,
    );
  }
}
