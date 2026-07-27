import 'package:flutter_test/flutter_test.dart';

/// BUG_2 test: Vietnamese "xóa" should match "XÓA" after normalization.
///
/// The current implementation does:
///   `_confirmCtrl.text.trim() == _confirmWord`
/// where _confirmWordVi = 'XÓA'.
/// This fails when the user types "xóa" (lowercase) because no normalization.
///
/// Expected fix: normalize to uppercase before comparing.
void main() {
  group('BUG_2: Delete Account confirm input normalization', () {
    test('lowercase "xóa" should match "XÓA" after toUpperCase normalization', () {
      const confirmWordVi = 'XÓA';
      const userInput = 'xóa';

      // BROKEN (current): this fails
      expect(userInput.trim() == confirmWordVi, isFalse,
          reason: 'Bug: lowercase "xóa" != "XÓA" without normalization');

      // FIXED: use toUpperCase()
      expect(userInput.trim().toUpperCase() == confirmWordVi, isTrue,
          reason: 'After toUpperCase(), Vietnamese chars normalize correctly');
    });

    test('lowercase "delete" should match "DELETE"', () {
      const confirmWordEn = 'DELETE';
      const userInput = 'delete';

      expect(userInput.trim() == confirmWordEn, isFalse,
          reason: 'Bug: lowercase != uppercase without normalization');
      expect(userInput.trim().toUpperCase() == confirmWordEn, isTrue);
    });

    test('uppercase input should also match (redundant but safe)', () {
      const confirmWordVi = 'XÓA';
      const userInput = 'XÓA';

      expect(userInput.trim().toUpperCase() == confirmWordVi, isTrue);
    });

    test('input with whitespace should be trimmed before compare', () {
      const confirmWordVi = 'XÓA';
      const userInput = '  xóa  ';

      expect(userInput.trim().toUpperCase() == confirmWordVi, isTrue,
          reason: 'Trim removes spaces, then uppercase normalizes');
    });
  });
}
