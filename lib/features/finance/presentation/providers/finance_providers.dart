import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../data/datasources/finance_remote_datasource.dart';
import '../../data/repositories/finance_repository_impl.dart';
import '../../domain/entities/contribution.dart';
import '../../domain/entities/saving_jar.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../domain/usecases/contribute_usecase.dart';
import '../../domain/usecases/create_jar_usecase.dart';
import '../../domain/usecases/delete_jar_usecase.dart';
import '../../domain/usecases/watch_contributions_usecase.dart';
import '../../domain/usecases/watch_jars_usecase.dart';
import '../../../../core/errors/failures.dart';

// ─── Data source & repository ─────────────────────────────────────────────────
final financeRemoteDataSourceProvider = Provider<FinanceRemoteDataSource>((ref) {
  return FinanceRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepositoryImpl(
    remoteDataSource: ref.watch(financeRemoteDataSourceProvider),
  );
});

// ─── Use case providers ──────────────────────────────────────────────────────
final watchJarsUseCaseProvider = Provider<WatchJarsUseCase>((ref) {
  return WatchJarsUseCase(ref.watch(financeRepositoryProvider));
});

final watchContributionsUseCaseProvider = Provider<WatchContributionsUseCase>((ref) {
  return WatchContributionsUseCase(ref.watch(financeRepositoryProvider));
});

final createJarUseCaseProvider = Provider<CreateJarUseCase>((ref) {
  return CreateJarUseCase(ref.watch(financeRepositoryProvider));
});

final contributeUseCaseProvider = Provider<ContributeUseCase>((ref) {
  return ContributeUseCase(ref.watch(financeRepositoryProvider));
});

final deleteJarUseCaseProvider = Provider<DeleteJarUseCase>((ref) {
  return DeleteJarUseCase(ref.watch(financeRepositoryProvider));
});

// ─── Stream providers ────────────────────────────────────────────────────────
final watchJarsProvider = StreamProvider.autoDispose<List<SavingJar>>((ref) {
  final coupleId = ref.watch(currentCoupleIdProvider);
  if (coupleId == null) return Stream.value(<SavingJar>[]);
  return ref.watch(watchJarsUseCaseProvider).call(coupleId);
});

final watchContributionsProvider =
    StreamProvider.autoDispose.family<List<Contribution>, String>((ref, jarId) {
  final coupleId = ref.watch(currentCoupleIdProvider);
  if (coupleId == null) return Stream.value(<Contribution>[]);
  return ref.watch(watchContributionsUseCaseProvider).call(coupleId, jarId);
});

// ─── Controllers ────────────────────────────────────────────────────────────
class CreateJarController extends StateNotifier<AsyncValue<void>> {
  CreateJarController({required CreateJarUseCase createJar})
      : _createJar = createJar,
        super(const AsyncValue.data(null));

  final CreateJarUseCase _createJar;

  Future<Either<Failure, Unit>?> createJar({
    required String coupleId,
    required String name,
    required String emoji,
    required int targetAmount,
    DateTime? deadline,
    int initialDeposit = 0,
    String? bankCode,
    String? bankAccountNumber,
    String? bankAccountName,
  }) async {
    state = const AsyncValue.loading();
    final result = await _createJar(
      coupleId: coupleId,
      name: name,
      emoji: emoji,
      targetAmount: targetAmount,
      deadline: deadline,
      initialDeposit: initialDeposit,
      bankCode: bankCode,
      bankAccountNumber: bankAccountNumber,
      bankAccountName: bankAccountName,
    );
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return Left<Failure, Unit>(failure);
      },
      (_) {
        state = const AsyncValue.data(null);
        return const Right<Failure, Unit>(unit);
      },
    );
  }
}

final createJarControllerProvider =
    StateNotifierProvider<CreateJarController, AsyncValue<void>>((ref) {
  return CreateJarController(
    createJar: ref.watch(createJarUseCaseProvider),
  );
});

class ContributeController extends StateNotifier<AsyncValue<void>> {
  ContributeController({required ContributeUseCase contribute})
      : _contribute = contribute,
        super(const AsyncValue.data(null));

  final ContributeUseCase _contribute;

  Future<Either<Failure, Unit>?> contribute({
    required String coupleId,
    required String jarId,
    required String userId,
    required String userName,
    required int amount,
    String? note,
    required String method,
  }) async {
    state = const AsyncValue.loading();
    final result = await _contribute(
      coupleId: coupleId,
      jarId: jarId,
      userId: userId,
      userName: userName,
      amount: amount,
      note: note,
      method: method,
    );
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return Left<Failure, Unit>(failure);
      },
      (_) {
        state = const AsyncValue.data(null);
        return const Right<Failure, Unit>(unit);
      },
    );
  }
}

final contributeControllerProvider =
    StateNotifierProvider<ContributeController, AsyncValue<void>>((ref) {
  return ContributeController(
    contribute: ref.watch(contributeUseCaseProvider),
  );
});

class DeleteJarController extends StateNotifier<AsyncValue<void>> {
  DeleteJarController({required DeleteJarUseCase deleteJar})
      : _deleteJar = deleteJar,
        super(const AsyncValue.data(null));

  final DeleteJarUseCase _deleteJar;

  Future<bool> deleteJar({required String coupleId, required String jarId}) async {
    state = const AsyncValue.loading();
    final result = await _deleteJar(coupleId: coupleId, jarId: jarId);
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

final deleteJarControllerProvider =
    StateNotifierProvider<DeleteJarController, AsyncValue<void>>((ref) {
  return DeleteJarController(
    deleteJar: ref.watch(deleteJarUseCaseProvider),
  );
});
