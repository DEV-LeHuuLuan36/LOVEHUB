import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/mood_entry.dart';
import '../../domain/repositories/mood_repository.dart';
import '../datasources/mood_remote_datasource.dart';

class MoodRepositoryImpl implements MoodRepository {
  MoodRepositoryImpl({required MoodRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final MoodRemoteDataSource _remoteDataSource;

  @override
  Stream<DailyMood> watchTodayMood(String coupleId, String myUid, String partnerUid) {
    return _remoteDataSource.watchTodayMood(coupleId, myUid, partnerUid);
  }

  @override
  Stream<List<DailyMood>> watchRecentMoods(
    String coupleId, {
    required String myUid,
    required String partnerUid,
    int days = 14,
  }) {
    return _remoteDataSource.watchRecentMoods(
      coupleId,
      myUid: myUid,
      partnerUid: partnerUid,
      days: days,
    );
  }

  @override
  Future<Either<Failure, SetMoodResult>> setMood({
    required String coupleId,
    required String uid,
    required String emoji,
    required String label,
    String? note,
  }) async {
    try {
      final result = await _remoteDataSource.setMood(
        coupleId: coupleId,
        uid: uid,
        emoji: emoji,
        label: label,
        note: note,
      );
      return Right(result);
    } on FirebaseException catch (e) {
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
