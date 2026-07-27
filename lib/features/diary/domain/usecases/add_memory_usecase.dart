import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/memory.dart';
import '../repositories/memory_repository.dart';

class AddMemoryUseCase {
  AddMemoryUseCase(this._repository);
  final MemoryRepository _repository;

  Future<Either<Failure, Memory>> call({
    required String coupleId,
    required String authorUid,
    required String title,
    String? story,
    required String category,
    required DateTime date,
    String? mood,
    required List<File> photos,
  }) {
    return _repository.addMemory(
      coupleId: coupleId,
      authorUid: authorUid,
      title: title,
      story: story,
      category: category,
      date: date,
      mood: mood,
      photos: photos,
    );
  }
}
