import '../entities/memory.dart';
import '../repositories/memory_repository.dart';

class WatchMemoriesUseCase {
  WatchMemoriesUseCase(this._repository);
  final MemoryRepository _repository;

  Stream<List<Memory>> call(String coupleId) {
    return _repository.watchMemories(coupleId);
  }
}
