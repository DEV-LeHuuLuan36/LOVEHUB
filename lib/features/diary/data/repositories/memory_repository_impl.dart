import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/memory.dart';
import '../../domain/repositories/memory_repository.dart';
import '../datasources/memory_remote_datasource.dart';

class MemoryRepositoryImpl implements MemoryRepository {
  MemoryRepositoryImpl({required MemoryRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final MemoryRemoteDataSource _remoteDataSource;

  @override
  Stream<List<Memory>> watchMemories(String coupleId) {
    return _remoteDataSource.watchMemories(coupleId);
  }

  @override
  Future<Either<Failure, Memory>> addMemory({
    required String coupleId,
    required String authorUid,
    required String title,
    String? story,
    required String category,
    required DateTime date,
    String? mood,
    required List<File> photos,
  }) async {
    try {
      final memory = await _remoteDataSource.addMemory(
        coupleId: coupleId,
        authorUid: authorUid,
        title: title,
        story: story,
        category: category,
        date: date,
        mood: mood,
        photos: photos,
      );
      return Right(memory);
    } on StorageException catch (e) {
      return Left(ServerFailure(e.message));
    } on FirebaseException catch (e) {
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteMemory({
    required String coupleId,
    required String memoryId,
  }) async {
    try {
      await _remoteDataSource.deleteMemory(
        coupleId: coupleId,
        memoryId: memoryId,
      );
      return const Right(unit);
    } on FirebaseException catch (e) {
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
