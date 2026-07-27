import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:lovehub/core/errors/failures.dart';
import 'package:lovehub/core/constants/firestore_paths.dart';
import 'package:lovehub/features/auth/domain/entities/app_user.dart';
import 'package:lovehub/features/couple/domain/entities/couple.dart';
import 'package:lovehub/features/settings/data/backup_json_codec.dart';
import 'package:lovehub/features/settings/domain/entities/backup_data.dart';
import 'package:lovehub/features/settings/domain/repositories/backup_repository.dart';

class BackupRepositoryImpl implements BackupRepository {
  BackupRepositoryImpl({
    required FirebaseFirestore firestore,
    required AppUser Function() getCurrentUser,
    required String? Function() getCoupleId,
    required Future<Couple?> Function(String) getCouple,
  })  : _fs = firestore,
        _getCurrentUser = getCurrentUser,
        _getCoupleId = getCoupleId,
        _getCouple = getCouple;

  final FirebaseFirestore _fs;
  final AppUser Function() _getCurrentUser;
  final String? Function() _getCoupleId;
  final Future<Couple?> Function(String) _getCouple;

  // ─── Export ──────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, BackupData>> exportAllData() async {
    try {
      final user = _getCurrentUser();
      final coupleId = _getCoupleId();

      // 1. User data (already in memory, no Firestore call needed).
      final userBackup = UserBackup(
        uid: user.uid,
        displayName: user.displayName ?? '',
        email: user.email,
        photoUrl: user.photoUrl,
      );

      // 2. Couple data.
      CoupleBackup? coupleBackup;
      Couple? couple;
      if (coupleId != null && coupleId.isNotEmpty) {
        couple = await _getCouple(coupleId);
        if (couple != null) {
          coupleBackup = CoupleBackup(
            partnerName: user.coupleId != null
                ? (user.displayName ?? '')
                : '', // populated below from partner doc
            partnerEmail: null,
            startDate: couple.startDate != null
                ? _dateStr(couple.startDate!)
                : '',
          );
        }
      }

      // 3. Streak. Guard with isNotEmpty to prevent "streaks/" invalid path.
      // [BUG_5] Wrap in try/catch — one bad collection must not fail export.
      StreakBackup streakBackup = const StreakBackup(
        currentStreak: 0,
        longestStreak: 0,
        recoveryTokens: 0,
        lastCheckin: '',
        lastTokenStreak: 0,
      );
      if (coupleId != null && coupleId.isNotEmpty) { // [BUG_4] added isNotEmpty
        try { // [BUG_5] added try/catch
          final streakSnap = await _fs.doc(FirestorePaths.streak(coupleId)).get();
          if (streakSnap.exists) {
            final d = streakSnap.data()!;
            streakBackup = StreakBackup(
              currentStreak: d['currentStreak'] as int? ?? 0,
              longestStreak: d['longestStreak'] as int? ?? 0,
              recoveryTokens: d['recoveryTokens'] as int? ?? 0,
              lastCheckin: d['lastCompleteDate'] as String? ?? '',
              lastTokenStreak: d['lastTokenStreak'] as int? ?? 0,
            );
          }
        } catch (e, st) {
          debugPrint('[BACKUP_ERR] streak read failed for coupleId=$coupleId: $e');
          debugPrint('[BACKUP_ERR] streak stacktrace: $st');
        }
      }

      // 4. Pet. Guard with isNotEmpty to prevent "pets/" invalid path.
      // [BUG_5] Wrap in try/catch.
      PetBackup? petBackup;
      if (coupleId != null && coupleId.isNotEmpty) { // [BUG_4] added isNotEmpty
        try { // [BUG_5] added try/catch
          final petSnap = await _fs.doc(FirestorePaths.pet(coupleId)).get();
          if (petSnap.exists) {
            final d = petSnap.data()!;
            petBackup = PetBackup(
              name: d['name'] as String? ?? 'Mochi',
              level: d['level'] as int? ?? 1,
              hp: d['hp'] as int? ?? 100,
              maxHp: d['maxHp'] as int? ?? 100,
              lovePoints: d['lovePoints'] as int? ?? 0,
              outfit: d['outfit'] as String?,
            );
          }
        } catch (e, st) {
          debugPrint('[BACKUP_ERR] pet read failed for coupleId=$coupleId: $e');
          debugPrint('[BACKUP_ERR] pet stacktrace: $st');
        }
      }

      // 5. Moods (last 30). Guard with isNotEmpty to prevent "moods/" invalid path.
      // [BUG_5] Wrap in try/catch.
      final moods = <MoodEntryBackup>[];
      if (coupleId != null && coupleId.isNotEmpty) { // [BUG_4] added isNotEmpty
        try { // [BUG_5] added try/catch
          final moodSnaps = await _fs
              .collection(FirestorePaths.moods(coupleId))
              .orderBy('updatedAt', descending: true)
              .limit(30)
              .get();
          for (final snap in moodSnaps.docs) {
            final d = snap.data();
            final updatedAt = d['updatedAt'] as Timestamp?;
            moods.add(MoodEntryBackup(
              date: updatedAt != null ? _dateStr(updatedAt.toDate()) : '',
              mood: d['label'] as String? ?? '',
              note: d['note'] as String?,
              emoji: d['emoji'] as String? ?? '',
            ));
          }
        } catch (e, st) {
          debugPrint('[BACKUP_ERR] moods read failed for coupleId=$coupleId: $e');
          debugPrint('[BACKUP_ERR] moods stacktrace: $st');
        }
      }

      // 6. Memories. Guard with isNotEmpty to prevent "diaries/" invalid path.
      // [BUG_5] Wrap in try/catch.
      final memories = <MemoryEntryBackup>[];
      if (coupleId != null && coupleId.isNotEmpty) { // [BUG_4] added isNotEmpty
        try { // [BUG_5] added try/catch
          final memSnaps = await _fs
              .collection(FirestorePaths.diaries(coupleId))
              .get();
          for (final snap in memSnaps.docs) {
            final d = snap.data();
            final date = d['date'] as Timestamp?;
            final createdAt = d['createdAt'] as Timestamp?;
            memories.add(MemoryEntryBackup(
              id: snap.id,
              title: d['title'] as String? ?? '',
              story: d['story'] as String?,
              category: d['category'] as String? ?? 'other',
              date: date != null ? _dateStr(date.toDate()) : '',
              imageUrls:
                  (d['photoUrls'] as List<dynamic>?)?.cast<String>() ?? [],
              mood: d['mood'] as String?,
              createdAt: createdAt != null ? createdAt.toDate().toIso8601String() : '',
            ));
          }
        } catch (e, st) {
          debugPrint('[BACKUP_ERR] memories read failed for coupleId=$coupleId: $e');
          debugPrint('[BACKUP_ERR] memories stacktrace: $st');
        }
      }

      // 7. Saving jars. Guard with isNotEmpty to prevent "savingJars/" invalid path.
      // [BUG_5] Wrap in try/catch.
      final jars = <SavingJarEntryBackup>[];
      if (coupleId != null && coupleId.isNotEmpty) { // [BUG_4] added isNotEmpty
        try { // [BUG_5] added try/catch
          final jarSnaps = await _fs
              .collection(FirestorePaths.savingJars(coupleId))
              .get();
          for (final snap in jarSnaps.docs) {
            final d = snap.data();
            final deadline = d['deadline'] as Timestamp?;
            jars.add(SavingJarEntryBackup(
              id: snap.id,
              name: d['name'] as String? ?? '',
              emoji: d['emoji'] as String? ?? '🐷',
              currentAmount: d['currentAmount'] as int? ?? 0,
              targetAmount: d['targetAmount'] as int? ?? 0,
              deadline: deadline?.toDate().toIso8601String(),
            ));
          }
        } catch (e, st) {
          debugPrint('[BACKUP_ERR] savingJars read failed for coupleId=$coupleId: $e');
          debugPrint('[BACKUP_ERR] savingJars stacktrace: $st');
        }
      }

      // 8. Milestones. Guard with isNotEmpty. [BUG_5] Wrap in try/catch.
      final milestones = <String>[];
      if (coupleId != null && coupleId.isNotEmpty) { // [BUG_4] added isNotEmpty
        try { // [BUG_5] added try/catch
          final msSnap = await _fs.doc('milestones/$coupleId').get();
          if (msSnap.exists) {
            milestones.addAll(
                (msSnap.data()?['list'] as List<dynamic>?)?.cast<String>() ?? []);
          }
        } catch (e, st) {
          debugPrint('[BACKUP_ERR] milestones read failed for coupleId=$coupleId: $e');
          debugPrint('[BACKUP_ERR] milestones stacktrace: $st');
        }
      }

      // 9. Location history. Guard with isNotEmpty. [BUG_5] Wrap in try/catch.
      final locations = <LocationEntryBackup>[];
      if (coupleId != null && coupleId.isNotEmpty) { // [BUG_4] added isNotEmpty
        try { // [BUG_5] added try/catch
          final locSnaps = await _fs
              .collection('locations/$coupleId/history')
              .orderBy('timestamp', descending: true)
              .limit(100)
              .get();
          for (final snap in locSnaps.docs) {
            final d = snap.data();
            locations.add(LocationEntryBackup(
              latitude: (d['latitude'] as num?)?.toDouble() ?? 0.0,
              longitude: (d['longitude'] as num?)?.toDouble() ?? 0.0,
              name: d['name'] as String?,
            ));
          }
        } catch (e, st) {
          debugPrint('[BACKUP_ERR] locations read failed for coupleId=$coupleId: $e');
          debugPrint('[BACKUP_ERR] locations stacktrace: $st');
        }
      }

      final data = BackupData(
        version: kBackupSchemaVersion,
        exportedAt: DateTime.now().toUtc().toIso8601String(),
        user: userBackup,
        couple: coupleBackup,
        streak: streakBackup,
        pet: petBackup,
        moods: moods,
        memories: memories,
        savingJars: jars,
        milestones: milestones,
        locationHistory: locations.isEmpty ? null : locations,
      );

      debugPrint('[BACKUP] Exported backup for uid=${user.uid}, coupleId=$coupleId');
      return Right(data);
    } on FirebaseException catch (e) {
      debugPrint('[BACKUP_ERR] exportAllData FirebaseException: '
          'code=${e.code} message=${e.message}');
      return Left(FirestoreFailure(e.message ?? 'Export failed'));
    } catch (e, st) {
      debugPrint('[BACKUP_ERR] exportAllData unexpected: $e\n$st');
      return Left(FirestoreFailure('Export failed: $e'));
    }
  }

  // ─── Import ─────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> importAllData(BackupData data) async {
    // Step 1: validate
    final validation = validateBackupData(data);
    if (validation.isLeft()) return validation;

    try {
      final user = _getCurrentUser();
      final coupleId = _getCoupleId();

      final batch = _fs.batch();

      // ── Streak (overwrite subcollection, partner keeps theirs) ────────────────
      if (coupleId != null && coupleId.isNotEmpty) { // [BUG_4] added isNotEmpty
        final streakRef = _fs.doc(FirestorePaths.streak(coupleId));
        batch.set(streakRef, {
          'currentStreak': data.streak.currentStreak,
          'longestStreak': data.streak.longestStreak,
          'recoveryTokens': data.streak.recoveryTokens,
          'lastCompleteDate': data.streak.lastCheckin,
          'lastTokenStreak': data.streak.lastTokenStreak,
        }, SetOptions(merge: true));
      }

      // ── Pet (overwrite subcollection) ────────────────────────────────────────
      if (coupleId != null && coupleId.isNotEmpty && data.pet != null) { // [BUG_4] added isNotEmpty
        final petRef = _fs.doc(FirestorePaths.pet(coupleId));
        batch.set(petRef, {
          'name': data.pet!.name,
          'level': data.pet!.level,
          'hp': data.pet!.hp,
          'maxHp': data.pet!.maxHp,
          'lovePoints': data.pet!.lovePoints,
          if (data.pet!.outfit != null) 'outfit': data.pet!.outfit,
        }, SetOptions(merge: true));
      }

      // ── Moods (delete old, write new) ───────────────────────────────────────
      if (coupleId != null && coupleId.isNotEmpty) { // [BUG_4] added isNotEmpty
        final moodCol = _fs.collection(FirestorePaths.moods(coupleId));
        // Collect existing doc ids so we can delete them.
        final existing = await moodCol.get();
        for (final d in existing.docs) {
          batch.delete(d.reference);
        }
        for (final mood in data.moods) {
          // Use date as stable doc id so re-importing the same backup is idempotent.
          final docId = '${mood.date}_${mood.mood}';
          batch.set(moodCol.doc(docId), {
            'label': mood.mood,
            'emoji': mood.emoji,
            'note': mood.note,
            'updatedAt': Timestamp.fromDate(DateTime.parse(mood.date)),
          }, SetOptions(merge: true));
        }
      }

      // ── Memories (delete old, write new) ─────────────────────────────────────
      if (coupleId != null && coupleId.isNotEmpty) { // [BUG_4] added isNotEmpty
        final diaryCol = _fs.collection(FirestorePaths.diaries(coupleId));
        final existing = await diaryCol.get();
        for (final d in existing.docs) {
          batch.delete(d.reference);
        }
        for (final mem in data.memories) {
          final memRef = diaryCol.doc(mem.id);
          batch.set(memRef, {
            'title': mem.title,
            if (mem.story != null) 'story': mem.story,
            'category': mem.category,
            'date': Timestamp.fromDate(DateTime.parse(mem.date)),
            'photoUrls': mem.imageUrls,
            if (mem.mood != null) 'mood': mem.mood,
            'authorUid': user.uid,
            'createdAt': Timestamp.fromDate(DateTime.parse(mem.createdAt)),
          }, SetOptions(merge: true));
        }
      }

      // ── Saving jars (delete old, write new) ──────────────────────────────────
      if (coupleId != null && coupleId.isNotEmpty) { // [BUG_4] added isNotEmpty
        final jarsCol = _fs.collection(FirestorePaths.savingJars(coupleId));
        final existing = await jarsCol.get();
        for (final d in existing.docs) {
          batch.delete(d.reference);
        }
        for (final jar in data.savingJars) {
          final jarRef = jarsCol.doc(jar.id);
          batch.set(jarRef, {
            'name': jar.name,
            'emoji': jar.emoji,
            'currentAmount': jar.currentAmount,
            'targetAmount': jar.targetAmount,
            if (jar.deadline != null && jar.deadline!.isNotEmpty)
              'deadline': Timestamp.fromDate(DateTime.parse(jar.deadline!)),
            'createdAt': Timestamp.now(),
          }, SetOptions(merge: true));
        }
      }

      // ── Milestones ────────────────────────────────────────────────────────────
      if (coupleId != null && coupleId.isNotEmpty) { // [BUG_4] added isNotEmpty
        final msRef = _fs.doc('milestones/$coupleId');
        batch.set(msRef, {'list': data.milestones}, SetOptions(merge: true));
      }

      // ── Location history ─────────────────────────────────────────────────────
      if (coupleId != null && coupleId.isNotEmpty && data.locationHistory != null) { // [BUG_4] added isNotEmpty
        final locCol = _fs.collection('locations/$coupleId/history');
        final existing = await locCol.get();
        for (final d in existing.docs) {
          batch.delete(d.reference);
        }
        int seq = 0;
        for (final loc in data.locationHistory!) {
          batch.set(locCol.doc('loc_$seq'), {
            'latitude': loc.latitude,
            'longitude': loc.longitude,
            if (loc.name != null) 'name': loc.name,
            'timestamp': Timestamp.now(),
          });
          seq++;
        }
      }

      await batch.commit();
      debugPrint('[BACKUP] Import committed for uid=${user.uid}, coupleId=$coupleId');
      return const Right(unit);
    } on FirebaseException catch (e) {
      debugPrint('[BACKUP_ERR] importAllData FirebaseException: '
          'code=${e.code} message=${e.message}');
      return Left(FirestoreFailure(e.message ?? 'Import failed'));
    } catch (e, st) {
      debugPrint('[BACKUP_ERR] importAllData unexpected: $e\n$st');
      return Left(FirestoreFailure('Import failed: $e'));
    }
  }

  // ─── Validation ───────────────────────────────────────────────────────────────

  @override
  Either<Failure, Unit> validateBackupData(BackupData data) {
    if (data.version == 0 || data.version > kBackupSchemaVersion) {
      return const Left(ValidationFailure(
          'Unsupported backup version. Please update LoveHub.'));
    }
    if (data.user.uid.isEmpty) {
      return const Left(ValidationFailure('Backup data is invalid: missing user uid.'));
    }
    return const Right(unit);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  static String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Convenience: converts a [BackupData] to a UTF-8 JSON string.
  static String toJsonString(BackupData data) => BackupJsonCodec.encode(data);

  /// Convenience: parses a UTF-8 JSON string into [BackupData].
  /// Throws [FormatException] if the string is not valid JSON or has the
  /// wrong structure.
  static BackupData fromJsonString(String json) => BackupJsonCodec.decode(json);
}
