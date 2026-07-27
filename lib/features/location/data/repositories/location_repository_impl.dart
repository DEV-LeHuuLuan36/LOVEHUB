import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/member_location.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_remote_datasource.dart';

class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl({required LocationRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final LocationRemoteDataSource _remoteDataSource;

  @override
  Stream<MemberLocation?> watchMemberLocation({
    required String coupleId,
    required String uid,
  }) {
    return _remoteDataSource.watchMemberLocation(
      coupleId: coupleId,
      uid: uid,
    );
  }

  @override
  Future<Either<Failure, void>> updateMyLocation({
    required String coupleId,
    required String uid,
    required double lat,
    required double lng,
  }) async {
    try {
      await _remoteDataSource.updateMyLocation(
        coupleId: coupleId,
        uid: uid,
        lat: lat,
        lng: lng,
      );
      return const Right(null);
    } on FirebaseException catch (e) {
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}