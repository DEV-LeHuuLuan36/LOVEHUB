import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/member_location.dart';

/// Domain-level interface for the couple-location sub-feature.
///
/// Reads use real-time Firestore snapshots so the UI re-renders
/// the moment either member writes a new position. Writes are kept
/// on a separate document so the high-frequency location writes
/// don't fight with the main user/couple docs (which carry
/// displayName, photoUrl, settings, etc.).
abstract class LocationRepository {
  /// Watches a single member's most-recent position. Emits
  /// `MemberLocation?` — `null` if the doc doesn't exist yet (no
  /// location has ever been written for that uid in this couple).
  Stream<MemberLocation?> watchMemberLocation({
    required String coupleId,
    required String uid,
  });

  /// Writes the current user's position. Uses `set(..., merge: true)`
  /// and a server timestamp for `updatedAt` so it's consistent
  /// across devices.
  Future<Either<Failure, void>> updateMyLocation({
    required String coupleId,
    required String uid,
    required double lat,
    required double lng,
  });
}