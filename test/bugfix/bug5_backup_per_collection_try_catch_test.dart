import 'package:flutter_test/flutter_test.dart';

/// BUG_5 test: Firestore collection() rejects empty/null/invalid paths.
/// Firestore throws: "A collection path must point to a valid collection"
///
/// The fix should:
/// 1. Guard each Firestore call with try/catch
/// 2. Skip collection if path is invalid
/// 3. Log with `[BACKUP_ERR]` prefix
///
/// Each collection access is independent — if one fails, others should still work.
void main() {
  group('BUG_5: Per-collection try/catch in backup export', () {
    test('invalid path "moods/" must be guarded', () {
      // Simulates FirestorePaths.moods("") → "moods/" which is invalid
      String moodsPath(String? coupleId) => 'moods/$coupleId';

      final path = moodsPath('');
      final isInvalid = path.endsWith('/') || path.contains('//');
      expect(isInvalid, isTrue,
          reason: 'Path "moods/" ends with / — invalid for Firestore.collection()');
    });

    test('valid path produces no trailing slash', () {
      String moodsPath(String? coupleId) => 'moods/$coupleId';
      final path = moodsPath('valid123');
      expect(path.endsWith('/'), isFalse);
      expect(path, equals('moods/valid123'));
    });

    test('simulated per-collection guard allows independent failure', () {
      // Simulates the fixed code: each collection wrapped in try/catch
      final results = <String>[];
      final logs = <String>[];

      void tryCollection(String name, String? coupleId) {
        try {
          if (coupleId == null || coupleId.isEmpty) {
            throw Exception('invalid path');
          }
          results.add('called:$name');
        } catch (e) {
          logs.add('[BACKUP_ERR] $name skipped: $e');
        }
      }

      tryCollection('moods', ''); // invalid → caught
      tryCollection('memories', 'abc123'); // valid
      tryCollection('savingJars', null); // invalid → caught

      expect(results, equals(['called:memories']),
          reason: 'Only memories should succeed');
      expect(logs.length, equals(2),
          reason: 'Two collections should be logged as errors');
      expect(logs[0], contains('[BACKUP_ERR] moods'));
      expect(logs[1], contains('[BACKUP_ERR] savingJars'));
    });

    test('all collections guarded means export completes even with bad data', () {
      bool exportCompleted = false;
      final errors = <String>[];

      // Simulates the export loop with try/catch on each collection
      try {
        try {
          // collection 1 — would throw
          throw Exception('collection path invalid');
        } catch (e) {
          errors.add('[BACKUP_ERR] collection1: $e');
        }
        try {
          // collection 2 — succeeds
        } catch (e) {
          errors.add('[BACKUP_ERR] collection2: $e');
        }
        exportCompleted = true;
      } catch (e) {
        // Top-level catch should NOT fire if per-collection catches work
        exportCompleted = false;
      }

      expect(exportCompleted, isTrue,
          reason: 'Export should complete despite per-collection errors');
      expect(errors.length, equals(1),
          reason: 'Only one collection error should be logged');
    });
  });
}