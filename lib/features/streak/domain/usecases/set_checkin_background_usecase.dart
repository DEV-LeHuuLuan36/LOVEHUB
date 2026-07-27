import 'dart:io';
import '../../../../core/errors/failures.dart';
import 'package:dartz/dartz.dart';
import '../../domain/repositories/checkin_background_repository.dart';

class SetCheckinBackgroundUseCase {
  SetCheckinBackgroundUseCase(this._repository);
  final CheckinBackgroundRepository _repository;

  Future<Either<Failure, Unit>> call({
    required String coupleId,
    required File image,
  }) =>
      _repository.setCheckinBackground(
        coupleId: coupleId,
        image: image,
      );
}
