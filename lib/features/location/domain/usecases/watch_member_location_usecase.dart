import '../entities/member_location.dart';
import '../repositories/location_repository.dart';

class WatchMemberLocationUseCase {
  WatchMemberLocationUseCase(this._repository);
  final LocationRepository _repository;

  Stream<MemberLocation?> call({
    required String coupleId,
    required String uid,
  }) {
    return _repository.watchMemberLocation(coupleId: coupleId, uid: uid);
  }
}