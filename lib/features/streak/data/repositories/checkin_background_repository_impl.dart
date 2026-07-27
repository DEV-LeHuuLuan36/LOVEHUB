import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../domain/repositories/checkin_background_repository.dart';
import '../datasources/checkin_background_remote_datasource.dart';

class CheckinBackgroundRepositoryImpl implements CheckinBackgroundRepository {
  CheckinBackgroundRepositoryImpl({
    required CheckinBackgroundRemoteDataSource remoteDataSource,
    required CloudinaryService cloudinary,
  })  : _remoteDataSource = remoteDataSource,
        _cloudinary = cloudinary;

  final CheckinBackgroundRemoteDataSource _remoteDataSource;
  final CloudinaryService _cloudinary;

  @override
  Stream<String?> watchCheckinBackground(String coupleId) {
    return _remoteDataSource.watchCheckinBackground(coupleId);
  }

  @override
  Future<Either<Failure, Unit>> setCheckinBackground({
    required String coupleId,
    required File image,
  }) async {
    try {
      debugPrint('CHK_BG_DBG: uploading background for coupleId=$coupleId');
      final url = await _cloudinary.uploadImage(image);
      debugPrint('CHK_BG_DBG: cloudinary url=$url');
      await _remoteDataSource.setCheckinBackground(coupleId, url);
      debugPrint('CHK_BG_DBG: firestore write ok');
      return const Right(unit);
    } on FirebaseException catch (e) {
      debugPrint('CHK_BG_DBG_ERR: FirebaseException ${e.code} ${e.message}');
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } catch (e, st) {
      debugPrint('CHK_BG_DBG_ERR: $e\n$st');
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> removeCheckinBackground(String coupleId) async {
    try {
      await _remoteDataSource.removeCheckinBackground(coupleId);
      return const Right(unit);
    } on FirebaseException catch (e) {
      return Left(ServerFailure(e.message ?? 'Firebase error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
