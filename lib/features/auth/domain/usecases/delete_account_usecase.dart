import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

/// Re-authenticates the current user with Google Sign-In. Required
/// before account deletion when the session is older than
/// Firebase's "recent login" window.
class ReauthenticateGoogleUseCase {
  const ReauthenticateGoogleUseCase(this._repository);
  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call() {
    return _repository.reauthenticateWithGoogle();
  }
}

/// Permanently deletes the current user's account and their
/// Firestore profile. The caller MUST invoke
/// [ReauthenticateGoogleUseCase] first; otherwise Firebase will
/// throw `requires-recent-login`.
class DeleteAccountUseCase {
  const DeleteAccountUseCase(this._repository);
  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call() {
    return _repository.deleteAccount();
  }
}
