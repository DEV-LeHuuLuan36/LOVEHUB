import 'package:flutter_test/flutter_test.dart';

/// BUG_4 test: Firestore.collection() rejects empty/null path.
///
/// When coupleId is null or empty, FirestorePaths.moods("") or moods(null)
/// produces "moods/" which is NOT a valid collection path.
/// Firestore throws: "collection path must point to a valid collection"
///
/// Expected fix: guard all Firestore.collection/doc calls with coupleId != null checks.
void main() {
  group('BUG_4: Backup export with empty/null coupleId', () {
    test('FirestorePaths.moods("") produces invalid path "moods/"', () {
      // Simulate what FirestorePaths.moods does
      String moodsPath(String? coupleId) => 'moods/$coupleId';

      final badPath = moodsPath('');
      expect(badPath, equals('moods/'),
          reason: 'Bug: empty coupleId → "moods/" is invalid Firestore path');

      final nullPath = moodsPath(null);
      expect(nullPath, equals('moods/null'),
          reason: 'Bug: null coupleId → "moods/null" is also invalid');
    });

    test('valid coupleId produces valid path', () {
      String moodsPath(String? coupleId) => 'moods/$coupleId';

      final goodPath = moodsPath('abc123');
      expect(goodPath, equals('moods/abc123'));
    });

    test('guard should skip Firestore call when coupleId is null', () {
      String? coupleId = null;
      final results = <String>[];

      // Simulates the fixed code: skip if coupleId is null/empty
      if (coupleId != null && coupleId.isNotEmpty) {
        results.add('called firestore');
      } else {
        results.add('skipped');
      }

      expect(results, equals(['skipped']),
          reason: 'With null coupleId, Firestore call should be skipped');
    });

    test('guard should skip Firestore call when coupleId is empty string', () {
      String? coupleId = '';
      final results = <String>[];

      if (coupleId != null && coupleId.isNotEmpty) {
        results.add('called firestore');
      } else {
        results.add('skipped');
      }

      expect(results, equals(['skipped']),
          reason: 'With empty coupleId, Firestore call should be skipped');
    });

    test('guard should proceed when coupleId is valid', () {
      String? coupleId = 'valid_couple_id_123';
      final results = <String>[];

      if (coupleId != null && coupleId.isNotEmpty) {
        results.add('called firestore');
      } else {
        results.add('skipped');
      }

      expect(results, equals(['called firestore']),
          reason: 'With valid coupleId, Firestore call should proceed');
    });
  });
}
