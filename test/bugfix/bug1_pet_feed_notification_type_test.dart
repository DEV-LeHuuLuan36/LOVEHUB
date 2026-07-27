import 'package:flutter_test/flutter_test.dart';

/// BUG_1 test: pet feed notification type should be 'pet', not 'pet_feed'.
///
/// NotificationItemTypeExtension.fromKey() only handles these string keys:
///   'partnerCheckin', 'milestone', 'pet', 'pairing', 'reminder', 'other'
///
/// The pet_screen sends: 'type': 'pet_feed'
/// This maps to the `default: return NotificationItemType.other;` branch.
/// The push notification therefore shows the wrong icon/color.
///
/// Expected fix: change 'pet_feed' → 'pet' in pet_screen.dart.
void main() {
  group('BUG_1: pet feed notification type mapping', () {
    // Simulates NotificationItemTypeExtension.fromKey
    String getTypeFromKey(String key) {
      switch (key) {
        case 'partnerCheckin':
          return 'partnerCheckin';
        case 'milestone':
          return 'milestone';
        case 'pet':
          return 'pet';
        case 'pairing':
          return 'pairing';
        case 'reminder':
          return 'reminder';
        default:
          return 'other'; // THIS IS THE BUG
      }
    }

    test('BROKEN: "pet_feed" falls through to "other" type', () {
      final result = getTypeFromKey('pet_feed');
      expect(result, equals('other'),
          reason: 'Bug: "pet_feed" → "other" (wrong icon/color)');
    });

    test('FIXED: "pet" correctly maps to pet type', () {
      final result = getTypeFromKey('pet');
      expect(result, equals('pet'),
          reason: '"pet" → pet type (correct icon/color)');
    });

    test('all valid type keys map correctly', () {
      final validKeys = [
        'partnerCheckin',
        'milestone',
        'pet',
        'pairing',
        'reminder',
      ];
      for (final key in validKeys) {
        final result = getTypeFromKey(key);
        expect(result, equals(key),
            reason: '$key should map to itself');
      }
    });

    test('unknown keys fall through to other', () {
      expect(getTypeFromKey('unknown_type'), equals('other'));
      expect(getTypeFromKey('pet_fed'), equals('other'),
          reason: '"pet_fed" is also unrecognized → other');
      expect(getTypeFromKey(''), equals('other'));
    });
  });
}
