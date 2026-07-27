import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/location_remote_datasource.dart';
import '../../data/repositories/location_repository_impl.dart';
import '../../data/services/location_service.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/usecases/update_my_location_usecase.dart';
import '../../domain/usecases/watch_member_location_usecase.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../../presence/presentation/providers/presence_providers.dart';

// ─── Data source, repository, service ────────────────────────────────────────
final locationRemoteDataSourceProvider =
    Provider<LocationRemoteDataSource>((ref) {
  return LocationRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepositoryImpl(
    remoteDataSource: ref.watch(locationRemoteDataSourceProvider),
  );
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// ─── Use case providers ──────────────────────────────────────────────────────
final watchMemberLocationUseCaseProvider =
    Provider<WatchMemberLocationUseCase>((ref) {
  return WatchMemberLocationUseCase(ref.watch(locationRepositoryProvider));
});

final updateMyLocationUseCaseProvider =
    Provider<UpdateMyLocationUseCase>((ref) {
  return UpdateMyLocationUseCase(ref.watch(locationRepositoryProvider));
});

// ─── Stream providers (autoDispose — tied to the screen) ─────────────────────
/// Real-time snapshot of the current user's location doc.
final myLocationProvider = StreamProvider.autoDispose((ref) {
  final coupleId = ref.watch(currentCoupleIdProvider);
  final myUid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (coupleId == null || myUid == null) {
    return const Stream.empty();
  }
  return ref.watch(watchMemberLocationUseCaseProvider).call(
        coupleId: coupleId,
        uid: myUid,
      );
});

/// Real-time snapshot of the partner's location doc.
final partnerLocationProvider = StreamProvider.autoDispose((ref) {
  final coupleId = ref.watch(currentCoupleIdProvider);
  final partnerId = ref.watch(partnerIdProvider);
  if (coupleId == null || partnerId == null) {
    return const Stream.empty();
  }
  return ref.watch(watchMemberLocationUseCaseProvider).call(
        coupleId: coupleId,
        uid: partnerId,
      );
});