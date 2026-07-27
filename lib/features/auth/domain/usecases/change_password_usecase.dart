import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

class ChangePasswordUseCase {
  ChangePasswordUseCase(this._repository);
  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call({
    required String currentPassword,
    required String newPassword,
  }) =>
      _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
}
