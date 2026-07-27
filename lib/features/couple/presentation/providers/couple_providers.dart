import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/couple_remote_datasource.dart';
import '../../data/repositories/couple_repository_impl.dart';
import '../../domain/entities/couple.dart';
import '../../domain/entities/love_duration.dart';
import '../../domain/repositories/couple_repository.dart';
import '../../domain/usecases/create_couple_usecase.dart';
import '../../domain/usecases/finalize_unlink_usecase.dart';
import '../../domain/usecases/join_couple_usecase.dart';
import '../../domain/usecases/recover_couple_usecase.dart';
import '../../domain/usecases/request_unlink_usecase.dart';
import '../../domain/usecases/update_start_date_usecase.dart';
import '../../domain/usecases/watch_couple_usecase.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/data/models/app_user_model.dart';
import '../../../presence/presentation/providers/presence_providers.dart';

// ─── Data source & repository ─────────────────────────────────────────────────
final coupleRemoteDataSourceProvider = Provider<CoupleRemoteDataSource>((ref) {
  return CoupleRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

final coupleRepositoryProvider = Provider<CoupleRepository>((ref) {
  return CoupleRepositoryImpl(
    remoteDataSource: ref.watch(coupleRemoteDataSourceProvider),
  );
});

// ─── Use case providers ──────────────────────────────────────────────────────
final createCoupleUseCaseProvider = Provider<CreateCoupleUseCase>((ref) {
  return CreateCoupleUseCase(ref.watch(coupleRepositoryProvider));
});

final joinCoupleUseCaseProvider = Provider<JoinCoupleUseCase>((ref) {
  return JoinCoupleUseCase(ref.watch(coupleRepositoryProvider));
});

final watchCoupleUseCaseProvider = Provider<WatchCoupleUseCase>((ref) {
  return WatchCoupleUseCase(ref.watch(coupleRepositoryProvider));
});

final updateStartDateUseCaseProvider = Provider<UpdateStartDateUseCase>((ref) {
  return UpdateStartDateUseCase(ref.watch(coupleRepositoryProvider));
});

final requestUnlinkUseCaseProvider = Provider<RequestUnlinkUseCase>((ref) {
  return RequestUnlinkUseCase(ref.watch(coupleRepositoryProvider));
});

final recoverCoupleUseCaseProvider = Provider<RecoverCoupleUseCase>((ref) {
  return RecoverCoupleUseCase(ref.watch(coupleRepositoryProvider));
});

final finalizeUnlinkUseCaseProvider = Provider<FinalizeUnlinkUseCase>((ref) {
  return FinalizeUnlinkUseCase(ref.watch(coupleRepositoryProvider));
});

// ─── Stream provider: watch couple by coupleId ────────────────────────────────
final watchCoupleProvider = StreamProvider.family<Couple?, String>((ref, coupleId) {
  return ref.watch(watchCoupleUseCaseProvider).call(coupleId);
});

// ─── Derived providers ────────────────────────────────────────────────────────
final currentCoupleIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.coupleId;
});

final tickerProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  );
});

final loveDurationProvider = Provider.autoDispose<LoveDuration?>((ref) {
  final coupleId = ref.watch(currentCoupleIdProvider);
  if (coupleId == null) return null;

  final coupleAsync = ref.watch(watchCoupleProvider(coupleId));
  final couple = coupleAsync.valueOrNull;
  if (couple == null) return null;

  final start = couple.startDate;
  if (start == null) return null;

  final nowAsync = ref.watch(tickerProvider);
  final now = nowAsync.valueOrNull ?? DateTime.now();
  return LoveDuration.from(start, now);
});

// ─── Auto-finalize on app start ───────────────────────────────────────────────
/// Runs finalizeUnlinkIfExpired once when coupleId is first available.
/// The [FutureProvider] ensures it runs only once (cached). No UI widget needed.
final autoFinalizeUnlinkProvider = FutureProvider<void>((ref) async {
  final coupleId = ref.watch(currentCoupleIdProvider);
  if (coupleId == null) return;
  await ref.read(finalizeUnlinkUseCaseProvider).call(coupleId);
});

// ─── Unlink controller ───────────────────────────────────────────────────────
class UnlinkController extends StateNotifier<AsyncValue<void>> {
  UnlinkController({
    required RequestUnlinkUseCase requestUnlink,
    required RecoverCoupleUseCase recoverCouple,
  })  : _requestUnlink = requestUnlink,
        _recoverCouple = recoverCouple,
        super(const AsyncValue.data(null));

  final RequestUnlinkUseCase _requestUnlink;
  final RecoverCoupleUseCase _recoverCouple;

  Future<bool> requestUnlink({required String coupleId, required String userId}) async {
    state = const AsyncValue.loading();
    final result = await _requestUnlink(coupleId: coupleId, userId: userId);
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

  Future<bool> recover({required String coupleId}) async {
    state = const AsyncValue.loading();
    final result = await _recoverCouple(coupleId);
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

final unlinkControllerProvider =
    StateNotifierProvider<UnlinkController, AsyncValue<void>>((ref) {
  return UnlinkController(
    requestUnlink: ref.watch(requestUnlinkUseCaseProvider),
    recoverCouple: ref.watch(recoverCoupleUseCaseProvider),
  );
});

// ─── UpdateStartDate controller ─────────────────────────────────────────────
class UpdateStartDateController extends StateNotifier<AsyncValue<void>> {
  UpdateStartDateController({required UpdateStartDateUseCase updateStartDate})
      : _updateStartDate = updateStartDate,
        super(const AsyncValue.data(null));

  final UpdateStartDateUseCase _updateStartDate;

  Future<bool> setStartDate(String coupleId, DateTime date) async {
    state = const AsyncValue.loading();
    final result = await _updateStartDate(coupleId: coupleId, date: date);
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

final updateStartDateControllerProvider =
    StateNotifierProvider<UpdateStartDateController, AsyncValue<void>>((ref) {
  return UpdateStartDateController(
    updateStartDate: ref.watch(updateStartDateUseCaseProvider),
  );
});

// ─── Couple linking controller ───────────────────────────────────────────────
class CoupleController extends StateNotifier<AsyncValue<Couple?>> {
  CoupleController({
    required CreateCoupleUseCase createCouple,
    required JoinCoupleUseCase joinCouple,
  })  : _createCouple = createCouple,
        _joinCouple = joinCouple,
        super(const AsyncValue.data(null));

  final CreateCoupleUseCase _createCouple;
  final JoinCoupleUseCase _joinCouple;

  Future<bool> createCode(String userId) async {
    state = const AsyncValue.loading();
    final result = await _createCouple(userId);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (couple) {
        state = AsyncValue.data(couple);
        return true;
      },
    );
  }

  Future<bool> joinWithCode({required String userId, required String code}) async {
    state = const AsyncValue.loading();
    final result = await _joinCouple(userId: userId, code: code);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (couple) {
        state = AsyncValue.data(couple);
        return true;
      },
    );
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final coupleControllerProvider =
    StateNotifierProvider<CoupleController, AsyncValue<Couple?>>((ref) {
  return CoupleController(
    createCouple: ref.watch(createCoupleUseCaseProvider),
    joinCouple: ref.watch(joinCoupleUseCaseProvider),
  );
});

// ─── Partner profile ──────────────────────────────────────────────────────────
/// Stream of the partner's AppUser profile from Firestore; null if not in a couple
final partnerProfileProvider = StreamProvider.autoDispose<AppUser?>((ref) {
  final partnerId = ref.watch(partnerIdProvider);
  if (partnerId == null) return Stream.value(null);
  return ref.watch(firestoreProvider).doc('users/$partnerId').snapshots().map((snap) {
    if (!snap.exists) return null;
    return AppUserModel.fromFirestore(snap.data()!, partnerId);
  });
});
