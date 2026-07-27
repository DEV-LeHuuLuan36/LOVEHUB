import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../data/datasources/memory_remote_datasource.dart';
import '../../data/repositories/memory_repository_impl.dart';
import '../../domain/entities/memory.dart';
import '../../domain/repositories/memory_repository.dart';
import '../../domain/usecases/add_memory_usecase.dart';
import '../../domain/usecases/delete_memory_usecase.dart';
import '../../domain/usecases/watch_memories_usecase.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryServiceImpl();
});

final memoryRemoteDataSourceProvider = Provider<MemoryRemoteDataSource>((ref) {
  return MemoryRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
    cloudinary: ref.watch(cloudinaryServiceProvider),
  );
});

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepositoryImpl(
    remoteDataSource: ref.watch(memoryRemoteDataSourceProvider),
  );
});

final watchMemoriesUseCaseProvider = Provider<WatchMemoriesUseCase>((ref) {
  return WatchMemoriesUseCase(ref.watch(memoryRepositoryProvider));
});

final addMemoryUseCaseProvider = Provider<AddMemoryUseCase>((ref) {
  return AddMemoryUseCase(ref.watch(memoryRepositoryProvider));
});

final deleteMemoryUseCaseProvider = Provider<DeleteMemoryUseCase>((ref) {
  return DeleteMemoryUseCase(ref.watch(memoryRepositoryProvider));
});

final watchMemoriesProvider = StreamProvider.autoDispose<List<Memory>>((ref) {
  final coupleId = ref.watch(currentCoupleIdProvider);
  if (coupleId == null) return Stream.value([]);
  return ref.watch(watchMemoriesUseCaseProvider).call(coupleId);
});

class AddMemoryController extends StateNotifier<AsyncValue<void>> {
  AddMemoryController({required AddMemoryUseCase addMemory})
      : _addMemory = addMemory,
        super(const AsyncValue.data(null));

  final AddMemoryUseCase _addMemory;

  Future<Memory?> addMemory({
    required String coupleId,
    required String authorUid,
    required String title,
    String? story,
    required String category,
    required DateTime date,
    String? mood,
    required List<File> photos,
  }) async {
    state = const AsyncValue.loading();
    final result = await _addMemory(
      coupleId: coupleId,
      authorUid: authorUid,
      title: title,
      story: story,
      category: category,
      date: date,
      mood: mood,
      photos: photos,
    );
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return null;
      },
      (memory) {
        state = const AsyncValue.data(null);
        return memory;
      },
    );
  }
}

final addMemoryControllerProvider =
    StateNotifierProvider<AddMemoryController, AsyncValue<void>>((ref) {
  return AddMemoryController(
    addMemory: ref.watch(addMemoryUseCaseProvider),
  );
});

class DeleteMemoryController extends StateNotifier<AsyncValue<void>> {
  DeleteMemoryController({required DeleteMemoryUseCase deleteMemory})
      : _deleteMemory = deleteMemory,
        super(const AsyncValue.data(null));

  final DeleteMemoryUseCase _deleteMemory;

  Future<bool> deleteMemory({
    required String coupleId,
    required String memoryId,
  }) async {
    state = const AsyncValue.loading();
    final result = await _deleteMemory(
      coupleId: coupleId,
      memoryId: memoryId,
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

final deleteMemoryControllerProvider =
    StateNotifierProvider<DeleteMemoryController, AsyncValue<void>>((ref) {
  return DeleteMemoryController(
    deleteMemory: ref.watch(deleteMemoryUseCaseProvider),
  );
});
