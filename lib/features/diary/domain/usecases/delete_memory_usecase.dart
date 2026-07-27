import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/memory_repository.dart';

class DeleteMemoryUseCase {
  DeleteMemoryUseCase(this._repository);
  final MemoryRepository _repository;

  Future<Either<Failure, Unit>> call({
    required String coupleId,
    required String memoryId,
  }) {
    return _repository.deleteMemory(
      coupleId: coupleId,
      memoryId: memoryId,
    );
  }
}
