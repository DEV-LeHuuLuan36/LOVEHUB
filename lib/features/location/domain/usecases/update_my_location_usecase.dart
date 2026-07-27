import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/location_repository.dart';

class UpdateMyLocationUseCase {
  UpdateMyLocationUseCase(this._repository);
  final LocationRepository _repository;

  Future<Either<Failure, void>> call({
    required String coupleId,
    required String uid,
    required double lat,
    required double lng,
  }) {
    return _repository.updateMyLocation(
      coupleId: coupleId,
      uid: uid,
      lat: lat,
      lng: lng,
    );
  }
}