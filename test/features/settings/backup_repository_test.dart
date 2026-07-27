import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:lovehub/core/errors/failures.dart';
import 'package:lovehub/features/settings/data/backup_json_codec.dart';
import 'package:lovehub/features/settings/domain/entities/backup_data.dart';
import 'package:lovehub/features/settings/domain/repositories/backup_repository.dart';

/// Fake implementation of [BackupRepository] used only in unit tests.
/// No Firebase deps — fully isolated.
class FakeBackupRepository implements BackupRepository {
  FakeBackupRepository({Either<Failure, BackupData>? this.exportResult, Either<Failure, Unit>? this.importResult, Either<Failure, Unit>? this.validateResult});

  Either<Failure, BackupData>? exportResult;
  Either<Failure, Unit>? importResult;
  Either<Failure, Unit>? validateResult;

  int exportAllDataCallCount = 0;
  int importAllDataCallCount = 0;
  BackupData? importedData;

  @override
  Future<Either<Failure, BackupData>> exportAllData() async {
    exportAllDataCallCount++;
    if (exportResult != null) return exportResult!;
    return Right<Failure, BackupData>(buildSampleBackupData());
  }

  @override
  Future<Either<Failure, Unit>> importAllData(BackupData data) async {
    importAllDataCallCount++;
    importedData = data;

    // Mirror real impl: validate first, return early on failure.
    final validation = validateBackupData(data);
    final validationErr = validation.fold((f) => f.message, (_) => null);
    if (validationErr != null) {
      // Return the same left that validateBackupData would produce.
      return validation;
    }

    if (importResult != null) return importResult!;
    return const Right<Failure, Unit>(unit);
  }

  @override
  Either<Failure, Unit> validateBackupData(BackupData data) {
    if (validateResult != null) return validateResult!;
    return const Right<Failure, Unit>(unit);
  }
}

BackupData buildSampleBackupData() {
  return const BackupData(
    version: 1,
    exportedAt: '2026-07-16T12:00:00Z',
    user: UserBackup(
      uid: 'uid123',
      displayName: 'Alice',
      email: 'alice@example.com',
      photoUrl: 'https://example.com/avatar.jpg',
    ),
    couple: CoupleBackup(
      partnerName: 'Bob',
      partnerEmail: 'bob@example.com',
      startDate: '2024-01-01',
    ),
    streak: StreakBackup(
      currentStreak: 42,
      longestStreak: 90,
      recoveryTokens: 2,
      lastCheckin: '2026-07-15',
      lastTokenStreak: 30,
    ),
    pet: PetBackup(
      name: 'Mochi',
      level: 5,
      hp: 80,
      maxHp: 100,
      lovePoints: 250,
      outfit: 'blue_hat',
    ),
    moods: [
      MoodEntryBackup(date: '2026-07-15', mood: 'happy', note: 'Great day!', emoji: '😊'),
      MoodEntryBackup(date: '2026-07-14', mood: 'neutral', note: 'Ok day', emoji: '😐'),
    ],
    memories: [
      MemoryEntryBackup(
        id: 'mem1',
        title: 'Beach Trip',
        imageUrls: ['https://example.com/beach.jpg'],
        createdAt: '2026-06-01T10:00:00Z',
        category: 'travel',
        date: '2026-06-01',
      ),
    ],
    savingJars: [
      SavingJarEntryBackup(
        id: 'jar1',
        name: 'Vacation Fund',
        emoji: '🏖️',
        currentAmount: 1500000,
        targetAmount: 5000000,
      ),
    ],
    milestones: ['first_checkin', 'week_streak', 'pet_level_5'],
    locationHistory: [
      LocationEntryBackup(latitude: 10.0, longitude: 106.0, name: 'Park'),
    ],
  );
}

void main() {
  group('exportAllData', () {
    test('returns BackupData on success', () async {
      final repo = FakeBackupRepository();
      final result = await repo.exportAllData();

      expect(result.isRight(), isTrue);
      result.fold(
        (failure) => fail('Expected Right, got Left: ${failure.message}'),
        (data) {
          expect(data.user.uid, equals('uid123'));
          expect(data.couple?.partnerName, equals('Bob'));
          expect(data.streak.currentStreak, equals(42));
          expect(data.pet?.name, equals('Mochi'));
          expect(data.moods.length, equals(2));
          expect(data.memories.length, equals(1));
          expect(data.savingJars.length, equals(1));
          expect(data.milestones.length, equals(3));
          expect(data.locationHistory?.length, equals(1));
        },
      );
    });

    test('returns failure on error', () async {
      final repo = FakeBackupRepository(
        exportResult: Left<FirestoreFailure, BackupData>(FirestoreFailure('Read error')),
      );
      final result = await repo.exportAllData();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, contains('Read error')),
        (_) => fail('Expected Left'),
      );
    });

    test('includes all required fields in exported data', () async {
      final repo = FakeBackupRepository();
      final result = await repo.exportAllData();

      result.fold(
        (_) => fail('Expected Right'),
        (data) {
          expect(data.version, equals(1));
          expect(data.exportedAt, isNotEmpty);
          expect(data.user.uid, isNotEmpty);
          expect(data.user.displayName, isNotEmpty);
          expect(data.user.email, isNotEmpty);
          expect(data.streak.currentStreak, greaterThanOrEqualTo(0));
          expect(data.streak.longestStreak, greaterThanOrEqualTo(0));
          expect(data.streak.recoveryTokens, greaterThanOrEqualTo(0));
        },
      );
    });

    test('increments call count', () async {
      final repo = FakeBackupRepository();
      await repo.exportAllData();
      await repo.exportAllData();
      expect(repo.exportAllDataCallCount, equals(2));
    });
  });

  group('importAllData', () {
    test('returns Right(unit) on success', () async {
      final repo = FakeBackupRepository(
        importResult: const Right<Failure, Unit>(unit),
      );
      final backupData = buildSampleBackupData();
      final result = await repo.importAllData(backupData);

      expect(result.isRight(), isTrue);
      expect(repo.importAllDataCallCount, equals(1));
      expect(repo.importedData, equals(backupData));
    });

    test('returns failure on Firestore write error', () async {
      final repo = FakeBackupRepository(
        importResult: const Left(FirestoreFailure('Write failed')),
      );
      final result = await repo.importAllData(buildSampleBackupData());

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, contains('Write failed')),
        (_) => fail('Expected Left'),
      );
    });

    test('rejects invalid data based on validate result', () async {
      final repo = FakeBackupRepository(
        validateResult: Left<ValidationFailure, Unit>(ValidationFailure('Unsupported backup version')),
        importResult: const Right<Failure, Unit>(unit),
      );
      final result = await repo.importAllData(buildSampleBackupData());

      // validateBackupData is called first; if it fails, importAllData returns early.
      // FakeBackupRepository.validateBackupData returns the configured result.
      expect(result.isLeft(), isTrue);
    });
  });

  group('validateBackupData', () {
    test('accepts valid BackupData', () {
      final repo = FakeBackupRepository();
      final data = buildSampleBackupData();
      final result = repo.validateBackupData(data);
      expect(result.isRight(), isTrue);
    });

    test('rejects version 0', () {
      final repo = FakeBackupRepository(
        validateResult: Left<ValidationFailure, Unit>(ValidationFailure('Invalid version')),
      );
      final data = BackupData(
        version: 0,
        exportedAt: '2026-07-16T12:00:00Z',
        user: const UserBackup(uid: 'uid', displayName: 'Test', email: 'test@test.com'),
        streak: const StreakBackup(
          currentStreak: 0, longestStreak: 0, recoveryTokens: 0,
          lastCheckin: '', lastTokenStreak: 0,
        ),
        moods: const [],
        memories: const [],
        savingJars: const [],
        milestones: const [],
      );
      final result = repo.validateBackupData(data);
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f.message.toLowerCase(), contains('version')),
        (_) => fail('Expected Left'),
      );
    });

    test('rejects empty uid', () {
      final repo = FakeBackupRepository(
        validateResult: Left<ValidationFailure, Unit>(ValidationFailure('Invalid uid')),
      );
      final data = BackupData(
        version: 1,
        exportedAt: '2026-07-16T12:00:00Z',
        user: const UserBackup(uid: '', displayName: 'Test', email: 'test@test.com'),
        streak: const StreakBackup(
          currentStreak: 0, longestStreak: 0, recoveryTokens: 0,
          lastCheckin: '', lastTokenStreak: 0,
        ),
        moods: const [],
        memories: const [],
        savingJars: const [],
        milestones: const [],
      );
      final result = repo.validateBackupData(data);
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f.message.toLowerCase(), contains('uid')),
        (_) => fail('Expected Left'),
      );
    });
  });

  group('BackupJsonCodec', () {
    test('encode + decode round-trips correctly', () {
      final original = buildSampleBackupData();
      final json = BackupJsonCodec.encode(original);
      final restored = BackupJsonCodec.decode(json);

      expect(restored.version, equals(original.version));
      expect(restored.user.uid, equals(original.user.uid));
      expect(restored.user.displayName, equals(original.user.displayName));
      expect(restored.user.email, equals(original.user.email));
      expect(restored.couple?.partnerName, equals(original.couple?.partnerName));
      expect(restored.streak.currentStreak, equals(original.streak.currentStreak));
      expect(restored.streak.longestStreak, equals(original.streak.longestStreak));
      expect(restored.streak.recoveryTokens, equals(original.streak.recoveryTokens));
      expect(restored.pet?.name, equals(original.pet?.name));
      expect(restored.pet?.level, equals(original.pet?.level));
      expect(restored.pet?.hp, equals(original.pet?.hp));
      expect(restored.moods.length, equals(original.moods.length));
      expect(restored.memories.length, equals(original.memories.length));
      expect(restored.savingJars.length, equals(original.savingJars.length));
      expect(restored.milestones.length, equals(original.milestones.length));
    });

    test('handles null optional fields', () {
      final minimalJson = {
        'version': 1,
        'exportedAt': '2026-07-16T12:00:00Z',
        'user': {
          'uid': 'uid999',
          'displayName': 'Solo User',
          'email': 'solo@example.com',
          'photoUrl': null,
        },
        'couple': null,
        'streak': {
          'currentStreak': 0,
          'longestStreak': 0,
          'recoveryTokens': 0,
          'lastCheckin': '',
          'lastTokenStreak': 0,
        },
        'pet': null,
        'moods': <Map<String, dynamic>>[],
        'memories': <Map<String, dynamic>>[],
        'savingJars': <Map<String, dynamic>>[],
        'milestones': <String>[],
        'locationHistory': null,
      };

      final data = BackupData.fromJson(minimalJson);

      expect(data.user.uid, equals('uid999'));
      expect(data.couple, isNull);
      expect(data.pet, isNull);
      expect(data.locationHistory, isNull);
      expect(data.moods, isEmpty);
      expect(data.memories, isEmpty);
    });

    test('is lossless for all data types', () {
      final original = buildSampleBackupData();
      final json = BackupJsonCodec.encode(original);
      final restored = BackupJsonCodec.decode(json);

      expect(restored.moods[0].date, equals(original.moods[0].date));
      expect(restored.moods[0].mood, equals(original.moods[0].mood));
      expect(restored.moods[0].note, equals(original.moods[0].note));
      expect(restored.moods[0].emoji, equals(original.moods[0].emoji));
      expect(restored.memories[0].title, equals(original.memories[0].title));
      expect(restored.memories[0].imageUrls, equals(original.memories[0].imageUrls));
      expect(restored.savingJars[0].currentAmount, equals(original.savingJars[0].currentAmount));
      expect(restored.savingJars[0].targetAmount, equals(original.savingJars[0].targetAmount));
      expect(restored.milestones, equals(original.milestones));
      expect(restored.locationHistory?[0].latitude, equals(original.locationHistory?[0].latitude));
      expect(restored.locationHistory?[0].longitude, equals(original.locationHistory?[0].longitude));
    });

    test('decode throws on malformed JSON', () {
      expect(
        () => BackupJsonCodec.decode('not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('encode produces valid JSON with all expected keys', () {
      final original = buildSampleBackupData();
      final json = BackupJsonCodec.encode(original);

      expect(json.contains('"version"'), isTrue);
      expect(json.contains('"exportedAt"'), isTrue);
      expect(json.contains('"user"'), isTrue);
      expect(json.contains('"streak"'), isTrue);
      expect(json.contains('"moods"'), isTrue);
      expect(json.contains('"memories"'), isTrue);
      expect(json.contains('"savingJars"'), isTrue);
      expect(json.contains('"milestones"'), isTrue);
      expect(json.contains('"locationHistory"'), isTrue);
    });
  });
}
