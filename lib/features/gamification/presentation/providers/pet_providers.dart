import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/pat_result.dart';
import '../../domain/entities/pet_entity.dart';
import '../../domain/repositories/pet_repository.dart';
import '../../domain/usecases/add_love_points_usecase.dart';
import '../../domain/usecases/feed_pet_usecase.dart';
import '../../domain/usecases/watch_pet_usecase.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../data/datasources/pet_remote_datasource.dart';
import '../../data/repositories/pet_repository_impl.dart';

final petRemoteDataSourceProvider = Provider<PetRemoteDataSource>((ref) {
  return PetRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

final petRepositoryProvider = Provider<PetRepository>((ref) {
  return PetRepositoryImpl(
    remoteDataSource: ref.watch(petRemoteDataSourceProvider),
  );
});

final watchPetUseCaseProvider = Provider<WatchPetUseCase>((ref) {
  return WatchPetUseCase(ref.watch(petRepositoryProvider));
});

final feedPetUseCaseProvider = Provider<FeedPetUseCase>((ref) {
  return FeedPetUseCase(ref.watch(petRepositoryProvider));
});

final addLovePointsUseCaseProvider = Provider<AddLovePointsUseCase>((ref) {
  return AddLovePointsUseCase(ref.watch(petRepositoryProvider));
});

final watchPetProvider = StreamProvider.autoDispose<PetEntity?>((ref) {
  final coupleId = ref.watch(currentCoupleIdProvider);
  if (coupleId == null) return Stream.value(null);
  return ref.watch(watchPetUseCaseProvider).call(coupleId);
});

class FeedPetController extends StateNotifier<AsyncValue<void>> {
  FeedPetController({required FeedPetUseCase feed})
      : _feed = feed,
        super(const AsyncValue.data(null));

  final FeedPetUseCase _feed;

  Future<bool> feed(String coupleId) async {
    state = const AsyncValue.loading();
    final result = await _feed(coupleId);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }
}

final feedPetControllerProvider =
    StateNotifierProvider<FeedPetController, AsyncValue<void>>((ref) {
  return FeedPetController(
    feed: ref.watch(feedPetUseCaseProvider),
  );
});

enum PatOutcome {
  awarded,
  capped,
}

class PatController extends StateNotifier<AsyncValue<void>> {
  PatController({required PetRepository repository})
      : _repository = repository,
        super(const AsyncValue.data(null));

  final PetRepository _repository;

  Future<PatOutcome> pat(String coupleId) async {
    state = const AsyncValue.loading();
    final result = await _repository.pat(coupleId);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return PatOutcome.capped;
      },
      (patResult) {
        state = const AsyncValue.data(null);
        return patResult is PatResultAwarded ? PatOutcome.awarded : PatOutcome.capped;
      },
    );
  }
}

final patControllerProvider =
    StateNotifierProvider<PatController, AsyncValue<void>>((ref) {
  return PatController(
    repository: ref.watch(petRepositoryProvider),
  );
});

class SetPetTypeController extends StateNotifier<AsyncValue<void>> {
  SetPetTypeController({required PetRepository repository})
      : _repository = repository,
        super(const AsyncValue.data(null));

  final PetRepository _repository;

  Future<bool> setPetType(String coupleId, PetType type, List<PetType> unlocked) async {
    if (!unlocked.contains(type)) {
      state = AsyncValue.error('Locked', StackTrace.current);
      return false;
    }
    state = const AsyncValue.loading();
    final result = await _repository.setPetType(coupleId, type);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }
}

final setPetTypeControllerProvider =
    StateNotifierProvider<SetPetTypeController, AsyncValue<void>>((ref) {
  return SetPetTypeController(
    repository: ref.watch(petRepositoryProvider),
  );
});
