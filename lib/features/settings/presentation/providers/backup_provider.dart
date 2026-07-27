import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../data/repositories/backup_repository_impl.dart';
import '../../domain/entities/backup_data.dart';
import '../../domain/repositories/backup_repository.dart';

// ─── Repository provider ────────────────────────────────────────────────────────
final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepositoryImpl(
    firestore: ref.watch(firestoreProvider),
    getCurrentUser: () => ref.read(authStateProvider).valueOrNull!,
    getCoupleId: () => ref.watch(currentCoupleIdProvider),
    getCouple: (coupleId) async {
      final repo = ref.read(coupleRepositoryProvider);
      final stream = repo.watchCouple(coupleId);
      final snapshot = await stream.first;
      return snapshot;
    },
  );
});

// ─── Backup controller ─────────────────────────────────────────────────────────
/// Drives the Backup & Restore UI. Exposes export and import operations
/// via [StateController] so the UI can observe loading / error states.
class BackupController extends StateNotifier<AsyncValue<void>> {
  BackupController({required BackupRepository repository})
      : _repo = repository,
        super(const AsyncValue.data(null));

  final BackupRepository _repo;

  /// Exports all user data to a JSON file and opens the system share sheet.
  ///
  /// On success the file is shared (or saved). On failure a message is returned
  /// so the UI can show a snackbar.
  /// Returns `null` on success, or an error message on failure.
  Future<String?> exportBackup() async {
    state = const AsyncValue.loading();
    final result = await _repo.exportAllData();
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return failure.message;
      },
      (data) async {
        try {
          final jsonString = BackupRepositoryImpl.toJsonString(data);
          final fileName = _buildFileName();
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsString(jsonString);

          await Share.shareXFiles(
            [XFile(file.path)],
            subject: 'LoveHub Backup',
            text: 'LoveHub data backup',
          );

          state = const AsyncValue.data(null);
          return null;
        } catch (e, st) {
          debugPrint('[BACKUP_UI_ERR] exportBackup write/share: $e\n$st');
          final msg = 'Could not share backup: $e';
          state = AsyncValue.error(msg, st);
          return msg;
        }
      },
    );
  }

  /// Picks a JSON backup file from the device and imports it.
  ///
  /// Returns `null` on success, or an error message on failure.
  /// The caller should show a confirmation dialog **before** calling this.
  Future<String?> importBackup() async {
    state = const AsyncValue.loading();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        state = const AsyncValue.data(null);
        return 'Cancelled';
      }

      final path = result.files.single.path;
      if (path == null) {
        state = const AsyncValue.data(null);
        return 'Could not read the selected file.';
      }

      final jsonString = await File(path).readAsString();
      final data = BackupRepositoryImpl.fromJsonString(jsonString);

      // Validate first (no Firestore write)
      final validation = _repo.validateBackupData(data);
      final validationErr = validation.fold((f) => f.message, (_) => null);
      if (validationErr != null) {
        state = AsyncValue.error(validationErr, StackTrace.current);
        return validationErr;
      }

      // Import via batch writes
      final importResult = await _repo.importAllData(data);
      return importResult.fold(
        (failure) {
          state = AsyncValue.error(failure.message, StackTrace.current);
          return failure.message;
        },
        (_) {
          state = const AsyncValue.data(null);
          return null;
        },
      );
    } on FormatException catch (e) {
      debugPrint('[BACKUP_UI_ERR] importBackup parse error: $e');
      const msg = 'Invalid backup file format.';
      state = AsyncValue.error(msg, StackTrace.current);
      return msg;
    } catch (e, st) {
      debugPrint('[BACKUP_UI_ERR] importBackup unexpected: $e\n$st');
      final msg = 'Import failed: $e';
      state = AsyncValue.error(msg, st);
      return msg;
    }
  }

  /// Pre-validates a JSON string (from the file picker) without writing
  /// to Firestore. Used by the confirmation dialog to show the user what
  /// will be imported.
  Either<String, BackupData>? previewFile(String jsonString) {
    try {
      final data = BackupRepositoryImpl.fromJsonString(jsonString);
      return Right(data);
    } on FormatException catch (e) {
      return Left('Invalid backup file: $e');
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }

  String _buildFileName() {
    final now = DateTime.now();
    final ts =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'lovehub_backup_$ts.json';
  }
}

final backupControllerProvider =
    StateNotifierProvider<BackupController, AsyncValue<void>>((ref) {
  return BackupController(
    repository: ref.watch(backupRepositoryProvider),
  );
});

/// Shortcut: returns true while export or import is in progress.
final backupIsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(backupControllerProvider).isLoading;
});
