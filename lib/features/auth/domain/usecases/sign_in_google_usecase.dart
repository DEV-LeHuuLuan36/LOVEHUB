import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class SignInGoogleUseCase {
  const SignInGoogleUseCase(this._repository);
  final AuthRepository _repository;

  Future<Either<Failure, AppUser>> call() {
    return _repository.signInWithGoogle();
  }
}
