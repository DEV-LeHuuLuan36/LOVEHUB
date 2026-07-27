import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

/// Per-couple settings for the Check-in / Streak screen.
abstract class CheckinBackgroundRepository {
  /// Emits the currently-configured background image URL (or `null`
  /// for the default dark background). Both partners see the same
  /// value in real time because the underlying doc is shared.
  Stream<String?> watchCheckinBackground(String coupleId);

  /// Uploads [image] to Cloudinary, then writes the resulting
  /// `secure_url` to `couples/{coupleId}.checkinBackgroundUrl`.
  Future<Either<Failure, Unit>> setCheckinBackground({
    required String coupleId,
    required File image,
  });

  /// Clears the field (reverts to the default dark background).
  Future<Either<Failure, Unit>> removeCheckinBackground(String coupleId);
}
