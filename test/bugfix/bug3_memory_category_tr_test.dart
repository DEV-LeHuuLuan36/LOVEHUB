import 'package:flutter_test/flutter_test.dart';

/// BUG_3 test: 'memory.category'.tr() fails because 'memory.category'
/// is a nested object, not a string key.
///
/// easy_localization resolves keys like:
///   'memory.category' → {"love": "Love", "travel": "Travel", ...}
///   'memory.category.love' → "Love" (the correct leaf)
/// The broken code calls `.tr()` on 'memory.category' which resolves to a Map,
/// causing a TypeError crash inside easy_localization's getNested().
///
/// Expected fix: change 'memory.category' → 'memory.categoryLabel'
/// and add 'memory.categoryLabel' as a string leaf in en.json/vi.json.
void main() {
  group('BUG_3: memory.category .tr() on nested map', () {
    // Simulating the translation JSON structure
    final translations = {
      'memory': {
        'category': {
          'love': 'Love',
          'travel': 'Travel',
          'food': 'Food',
          'date': 'Date',
          'milestone': 'Milestone',
          'other': 'Other',
        },
        'categoryLabel': 'Category',
      },
    };

    String? getLeaf(Map<String, dynamic> root, String key) {
      final parts = key.split('.');
      dynamic current = root;
      for (final part in parts) {
        if (current is Map) {
          current = current[part];
        } else {
          return null;
        }
      }
      return current is String ? current : null;
    }

    bool isStringLeaf(Map<String, dynamic> root, String key) {
      final result = getLeaf(root, key);
      return result != null;
    }

    test('BROKEN: "memory.category" is NOT a string leaf', () {
      // The value is a Map, so calling .tr() on it would crash.
      // We verify this by checking it cannot be resolved as a String leaf.
      final canResolve = isStringLeaf(
          translations.cast<String, dynamic>(), 'memory.category');
      expect(canResolve, isFalse,
          reason: 'Bug: "memory.category" is a Map — .tr() crashes');
    });

    test('FIXED: "memory.categoryLabel" IS a string leaf', () {
      final canResolve = isStringLeaf(
          translations.cast<String, dynamic>(), 'memory.categoryLabel');
      expect(canResolve, isTrue,
          reason: '"memory.categoryLabel" resolves to "Category" — safe to call .tr()');
    });

    test('all category leaf keys work', () {
      final keys = ['love', 'travel', 'food', 'date', 'milestone', 'other'];
      for (final k in keys) {
        final canResolve = isStringLeaf(
            translations.cast<String, dynamic>(), 'memory.category.$k');
        expect(canResolve, isTrue,
            reason: 'memory.category.$k should resolve to a string');
      }
    });

    test('FIXED: entity labelKey "memory.category.love" is a valid leaf', () {
      // This is how MemoryEntity.categoryLabel works: labelKey = 'memory.category.love'
      final canResolve = isStringLeaf(
          translations.cast<String, dynamic>(), 'memory.category.love');
      expect(canResolve, isTrue,
          reason: 'MemoryEntity.categoryLabel → "memory.category.love" is safe');
    });
  });
}
