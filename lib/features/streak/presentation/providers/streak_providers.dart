import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/checkin_background_remote_datasource.dart';
import '../../data/datasources/streak_remote_datasource.dart';
import '../../data/repositories/checkin_background_repository_impl.dart';
import '../../data/repositories/streak_repository_impl.dart';
import '../../domain/entities/streak_entity.dart';
import '../../domain/repositories/checkin_background_repository.dart';
import '../../domain/repositories/streak_repository.dart';
import '../../domain/usecases/check_in_usecase.dart';
import '../../domain/usecases/remove_checkin_background_usecase.dart';
import '../../domain/usecases/set_checkin_background_usecase.dart';
import '../../domain/usecases/use_recovery_token_usecase.dart';
import '../../domain/usecases/watch_checkin_background_usecase.dart';
import '../../domain/usecases/watch_streak_usecase.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../../diary/presentation/providers/memory_providers.dart';
import '../../../notifications/domain/entities/notification_item.dart';
import '../../../notifications/presentation/providers/inbox_providers.dart';
import '../../../gamification/presentation/providers/pet_providers.dart';

// ─── Data source & repository ─────────────────────────────────────────────────
final streakRemoteDataSourceProvider = Provider<StreakRemoteDataSource>((ref) {
  return StreakRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

final streakRepositoryProvider = Provider<StreakRepository>((ref) {
  return StreakRepositoryImpl(
    remoteDataSource: ref.watch(streakRemoteDataSourceProvider),
  );
});

// ─── Check-in background ───────────────────────────────────────────────────────
final checkinBackgroundRemoteDataSourceProvider =
    Provider<CheckinBackgroundRemoteDataSource>((ref) {
  return CheckinBackgroundRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

final checkinBackgroundRepositoryProvider =
    Provider<CheckinBackgroundRepository>((ref) {
  return CheckinBackgroundRepositoryImpl(
    remoteDataSource: ref.watch(checkinBackgroundRemoteDataSourceProvider),
    cloudinary: ref.watch(cloudinaryServiceProvider),
  );
});

final watchCheckinBackgroundUseCaseProvider =
    Provider<WatchCheckinBackgroundUseCase>((ref) {
  return WatchCheckinBackgroundUseCase(
    ref.watch(checkinBackgroundRepositoryProvider),
  );
});

final setCheckinBackgroundUseCaseProvider =
    Provider<SetCheckinBackgroundUseCase>((ref) {
  return SetCheckinBackgroundUseCase(
    ref.watch(checkinBackgroundRepositoryProvider),
  );
});

final removeCheckinBackgroundUseCaseProvider =
    Provider<RemoveCheckinBackgroundUseCase>((ref) {
  return RemoveCheckinBackgroundUseCase(
    ref.watch(checkinBackgroundRepositoryProvider),
  );
});

/// Streams the current check-in screen background URL for the
/// current couple, or `null` for the default dark gradient.
final watchCheckinBackgroundProvider = StreamProvider.autoDispose<String?>((ref) {
  final coupleId = ref.watch(currentCoupleIdProvider);
  if (coupleId == null) return Stream.value(null);
  return ref.watch(watchCheckinBackgroundUseCaseProvider).call(coupleId);
});

// ─── Use case providers ───────────────────────────────────────────────────────
final watchStreakUseCaseProvider = Provider<WatchStreakUseCase>((ref) {
  return WatchStreakUseCase(ref.watch(streakRepositoryProvider));
});

final checkInUseCaseProvider = Provider<CheckInUseCase>((ref) {
  return CheckInUseCase(ref.watch(streakRepositoryProvider));
});

final useRecoveryTokenUseCaseProvider = Provider<UseRecoveryTokenUseCase>((ref) {
  return UseRecoveryTokenUseCase(ref.watch(streakRepositoryProvider));
});

// ─── Stream provider: watch streak by coupleId ────────────────────────────────
/// Watches the streak for the current couple. Returns null if not in a couple.
final watchStreakProvider = StreamProvider.autoDispose<StreakEntity?>((ref) {
  final coupleId = ref.watch(currentCoupleIdProvider);
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final partner = ref.watch(partnerProfileProvider).valueOrNull;

  if (coupleId == null || authUser == null || partner == null) {
    return Stream.value(null);
  }

  return ref.watch(watchStreakUseCaseProvider).call(
    coupleId: coupleId,
    myUid: authUser.uid,
    partnerId: partner.uid,
  );
});

/// Notifier that tracks the previous `partnerCheckedToday` value and
/// fires a local notification when it transitions from false to true.
class PartnerCheckinTracker {
  bool? _previous;

  void updateAndNotify({
    required StreakEntity? streak,
    required NotificationInboxNotifier inbox,
  }) {
    if (streak == null) return;
    final current = streak.partnerCheckedToday;
    if (_previous == false && current) {
      _previous = current;
      inbox.append(
        title: 'Partner checked in! 💕',
        body: 'Your partner has checked in today.',
        type: NotificationItemType.partnerCheckin,
      );
    } else {
      _previous = current;
    }
  }
}

/// Provider that holds a single PartnerCheckinTracker instance per container.
final partnerCheckinTrackerProvider = Provider<PartnerCheckinTracker>((ref) {
  return PartnerCheckinTracker();
});

/// Listens to the streak stream and records partner check-in events
/// into the local notification inbox.
final partnerCheckinInboxNotifierProvider = StreamProvider<void>((ref) {
  final tracker = ref.watch(partnerCheckinTrackerProvider);
  final streakAsync = ref.watch(watchStreakProvider);
  final inbox = ref.watch(notificationInboxProvider.notifier);

  streakAsync.whenData((streak) {
    tracker.updateAndNotify(streak: streak, inbox: inbox);
  });

  return const Stream.empty();
});

/// Notifier that tracks the previous pet HP value and fires a
/// notification when HP drops below 30.
class PetHpTracker {
  int? _previousHp;

  void updateAndNotify({
    required dynamic pet,
    required NotificationInboxNotifier inbox,
  }) {
    if (pet == null) return;
    final hp = pet.hp as int;
    if (_previousHp != null && _previousHp! >= 30 && hp < 30) {
      _previousHp = hp;
      inbox.append(
        title: 'Pet needs care! 🐱',
        body: 'Your pet HP is low. Tap to feed and take care of it.',
        type: NotificationItemType.pet,
      );
    } else {
      _previousHp = hp;
    }
  }
}

final petHpTrackerProvider = Provider<PetHpTracker>((ref) {
  return PetHpTracker();
});

final petHpInboxNotifierProvider = StreamProvider<void>((ref) {
  final tracker = ref.watch(petHpTrackerProvider);
  final petAsync = ref.watch(watchPetProvider);
  final inbox = ref.watch(notificationInboxProvider.notifier);

  petAsync.whenData((pet) {
    tracker.updateAndNotify(pet: pet, inbox: inbox);
  });

  return const Stream.empty();
});

// ─── Check-in controller ───────────────────────────────────────────────────────
class CheckInController extends StateNotifier<AsyncValue<void>> {
  CheckInController({required CheckInUseCase checkIn})
      : _checkIn = checkIn,
        super(const AsyncValue.data(null));

  final CheckInUseCase _checkIn;

  /// Returns:
  ///   - `null` on success (controller state → data, ready for the
  ///     UI to refresh and the partner push to fire).
  ///   - a non-null error string on failure (controller state →
  ///     error). The screen surfaces this as a snackbar.
  Future<String?> checkIn({
    required String coupleId,
    required String myUid,
    required String partnerId,
  }) async {
    state = const AsyncValue.loading();
    final result = await _checkIn(
      coupleId: coupleId,
      myUid: myUid,
      partnerId: partnerId,
    );
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return failure.message;
      },
      (_) {
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }
}

final checkInControllerProvider =
    StateNotifierProvider<CheckInController, AsyncValue<void>>((ref) {
  return CheckInController(
    checkIn: ref.watch(checkInUseCaseProvider),
  );
});

// ─── Recovery token controller ───────────────────────────────────────────────────
class UseRecoveryTokenController extends StateNotifier<AsyncValue<void>> {
  UseRecoveryTokenController({required UseRecoveryTokenUseCase useRecovery})
      : _useRecovery = useRecovery,
        super(const AsyncValue.data(null));

  final UseRecoveryTokenUseCase _useRecovery;

  Future<bool> useRecoveryToken({
    required String coupleId,
    required String myUid,
    required String partnerId,
  }) async {
    state = const AsyncValue.loading();
    final result = await _useRecovery(
      coupleId: coupleId,
      myUid: myUid,
      partnerId: partnerId,
    );
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

final useRecoveryTokenControllerProvider =
    StateNotifierProvider<UseRecoveryTokenController, AsyncValue<void>>((ref) {
  return UseRecoveryTokenController(
    useRecovery: ref.watch(useRecoveryTokenUseCaseProvider),
  );
});

// ─── Check-in background controller ────────────────────────────────────────────
/// Drives the "Change background" / "Remove background" actions.
/// `state.isLoading` is true while the image is uploading to
/// Cloudinary; `state.hasError` carries the failure message.
class CheckinBackgroundController extends StateNotifier<AsyncValue<void>> {
  CheckinBackgroundController({
    required SetCheckinBackgroundUseCase setBackground,
    required RemoveCheckinBackgroundUseCase removeBackground,
  })  : _setBackground = setBackground,
        _removeBackground = removeBackground,
        super(const AsyncValue.data(null));

  final SetCheckinBackgroundUseCase _setBackground;
  final RemoveCheckinBackgroundUseCase _removeBackground;

  Future<String?> setBackground({
    required String coupleId,
    required File image,
  }) async {
    state = const AsyncValue.loading();
    final result = await _setBackground(
      coupleId: coupleId,
      image: image,
    );
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return failure.message;
      },
      (_) {
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }

  Future<String?> removeBackground(String coupleId) async {
    state = const AsyncValue.loading();
    final result = await _removeBackground(coupleId);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return failure.message;
      },
      (_) {
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }
}

final checkinBackgroundControllerProvider =
    StateNotifierProvider<CheckinBackgroundController, AsyncValue<void>>((ref) {
  return CheckinBackgroundController(
    setBackground: ref.watch(setCheckinBackgroundUseCaseProvider),
    removeBackground: ref.watch(removeCheckinBackgroundUseCaseProvider),
  );
});
