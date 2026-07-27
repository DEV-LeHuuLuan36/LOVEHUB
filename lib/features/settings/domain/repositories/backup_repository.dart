import 'package:dartz/dartz.dart';
import 'package:lovehub/core/errors/failures.dart';
import 'package:lovehub/features/settings/domain/entities/backup_data.dart';

/// Repository interface for backup / restore operations.
///
/// Follows Clean Architecture rules:
/// - Interface lives in the domain layer (no Firestore / Firebase deps).
/// - Implementation lives in the data layer.
abstract class BackupRepository {
  /// Reads all user + couple data from Firestore and bundles it into a
  /// [BackupData] snapshot tagged with the current UTC timestamp.
  ///
  /// Returns [Right(BackupData)] on success or [Left(FirestoreFailure)] on
  /// any read error.
  Future<Either<Failure, BackupData>> exportAllData();

  /// Validates and imports a [BackupData] snapshot back into Firestore.
  ///
  /// Steps:
  /// 1. Schema version check — rejects backups with unsupported versions.
  /// 2. Required-field validation (uid must be non-empty).
  /// 3. Firestore batch writes for streak, pet, moods, memories, jars,
  ///    milestones, and location history.
  ///
  /// NOTE: importing does NOT overwrite the `users/{uid}` document or the
  /// `couples/{coupleId}` document — those are owned by the running app.
  /// Shared subcollection data (streak, pet, moods, etc.) is overwritten.
  ///
  /// Returns [Right(unit)] on success,
  /// [Left(ValidationFailure)] if the data fails validation, or
  /// [Left(FirestoreFailure)] if Firestore writes fail.
  Future<Either<Failure, Unit>> importAllData(BackupData data);

  /// Quick validation without writing anything.
  /// Returns [Right(unit)] if [data] can be imported, [Left(ValidationFailure)] otherwise.
  Either<Failure, Unit> validateBackupData(BackupData data);
}
