import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/memory.dart';

abstract class MemoryRepository {
  Stream<List<Memory>> watchMemories(String coupleId);

  Future<Either<Failure, Memory>> addMemory({
    required String coupleId,
    required String authorUid,
    required String title,
    String? story,
    required String category,
    required DateTime date,
    String? mood,
    required List<File> photos,
  });

  Future<Either<Failure, Unit>> deleteMemory({
    required String coupleId,
    required String memoryId,
  });
}
