import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/mood_remote_datasource.dart';
import '../../data/repositories/mood_repository_impl.dart';
import '../../domain/entities/mood_entry.dart';
import '../../domain/repositories/mood_repository.dart';
import '../../domain/usecases/set_mood_usecase.dart';
import '../../domain/usecases/watch_recent_moods_usecase.dart';
import '../../domain/usecases/watch_today_mood_usecase.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../../presence/presentation/providers/presence_providers.dart';

final moodRemoteDataSourceProvider = Provider<MoodRemoteDataSource>((ref) {
  return MoodRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

final moodRepositoryProvider = Provider<MoodRepository>((ref) {
  return MoodRepositoryImpl(
    remoteDataSource: ref.watch(moodRemoteDataSourceProvider),
  );
});

final watchTodayMoodUseCaseProvider = Provider<WatchTodayMoodUseCase>((ref) {
  return WatchTodayMoodUseCase(ref.watch(moodRepositoryProvider));
});

final watchRecentMoodsUseCaseProvider = Provider<WatchRecentMoodsUseCase>((ref) {
  return WatchRecentMoodsUseCase(ref.watch(moodRepositoryProvider));
});

final setMoodUseCaseProvider = Provider<SetMoodUseCase>((ref) {
  return SetMoodUseCase(ref.watch(moodRepositoryProvider));
});

final watchTodayMoodProvider = StreamProvider.autoDispose<DailyMood?>((ref) {
  final coupleId = ref.watch(currentCoupleIdProvider);
  final myUser = ref.watch(authStateProvider).valueOrNull;
  final partnerId = ref.watch(partnerIdProvider);
  if (coupleId == null || myUser?.uid == null || partnerId == null) {
    return Stream.value(null);
  }
  return ref.watch(watchTodayMoodUseCaseProvider).call(
    coupleId,
    myUser!.uid,
    partnerId,
  );
});

/// Streams the most recent N daily mood docs for the current
/// couple, newest first. N defaults to 14 (covers "Last 7 Days"
/// plus the Recent Moods list).
final watchRecentMoodsProvider =
    StreamProvider.autoDispose.family<List<DailyMood>, int>((ref, days) {
  final coupleId = ref.watch(currentCoupleIdProvider);
  final myUser = ref.watch(authStateProvider).valueOrNull;
  final partnerId = ref.watch(partnerIdProvider);
  if (coupleId == null || myUser?.uid == null || partnerId == null) {
    return Stream.value(const <DailyMood>[]);
  }
  return ref.watch(watchRecentMoodsUseCaseProvider).call(
    coupleId,
    myUid: myUser!.uid,
    partnerUid: partnerId,
    days: days,
  );
});

class SetMoodController extends StateNotifier<AsyncValue<void>> {
  SetMoodController({required SetMoodUseCase setMood})
      : _setMood = setMood,
        super(const AsyncValue.data(null));

  final SetMoodUseCase _setMood;

  Future<SetMoodResult?> setMood({
    required String coupleId,
    required String uid,
    required String emoji,
    required String label,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    final result = await _setMood(
      coupleId: coupleId,
      uid: uid,
      emoji: emoji,
      label: label,
      note: note,
    );
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return null;
      },
      (data) {
        state = const AsyncValue.data(null);
        return data;
      },
    );
  }
}

final setMoodControllerProvider =
    StateNotifierProvider<SetMoodController, AsyncValue<void>>((ref) {
  return SetMoodController(
    setMood: ref.watch(setMoodUseCaseProvider),
  );
});
