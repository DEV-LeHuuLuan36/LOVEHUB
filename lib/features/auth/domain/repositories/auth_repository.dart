import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();

  Future<Either<Failure, AppUser>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<Either<Failure, AppUser>> signInWithGoogle();

  /// Re-authenticates the current user with their current password
  /// and sets a new one. Only valid for email/password accounts.
  /// The data source decides whether the current user has a
  /// 'password' provider; if not, returns [AuthFailure].
  Future<Either<Failure, Unit>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Either<Failure, Unit>> signOut();

  /// Re-authenticates the current user via Google Sign-In. Required
  /// before sensitive operations like account deletion when the
  /// session is older than Firebase's "recent login" window.
  Future<Either<Failure, Unit>> reauthenticateWithGoogle();

  /// Permanently deletes the current user's account and their
  /// Firestore profile. The caller MUST invoke
  /// [reauthenticateWithGoogle] first; otherwise Firebase will
  /// throw `requires-recent-login`.
  ///
  /// As a side effect, if the user is in a couple, the partner's
  /// `coupleId` is cleared so they are returned to a single state.
  /// Shared couple data (memories, moods, streaks, jars, etc.) is
  /// left intact for the partner.
  Future<Either<Failure, Unit>> deleteAccount();
}
