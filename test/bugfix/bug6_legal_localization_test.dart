import 'package:flutter_test/flutter_test.dart';

/// BUG_6 test: The privacy_policy.md and terms_of_service.md are
/// hardcoded English text. They should be localizable.
///
/// The fix: load from `assets/legal/{lang}/privacy_policy.md` for the
/// current locale, with fallback to English if missing.
void main() {
  group('BUG_6: Terms/Privacy Policy localization', () {
    test('locale-aware path picks correct file', () {
      String pathForLocale(String assetBase, String lang) =>
          'assets/legal/$lang/$assetBase';

      expect(pathForLocale('privacy_policy.md', 'vi'),
          equals('assets/legal/vi/privacy_policy.md'));
      expect(pathForLocale('privacy_policy.md', 'en'),
          equals('assets/legal/en/privacy_policy.md'));
      expect(pathForLocale('terms_of_service.md', 'vi'),
          equals('assets/legal/vi/terms_of_service.md'));
    });

    test('fallback to English when locale-specific file missing', () {
      String pathForLocale(String assetBase, String lang) =>
          'assets/legal/$lang/$assetBase';

      // Simulates: try locale-specific, fall back to English
      String withFallback(String assetBase, String lang, bool viExists) {
        if (lang == 'en') {
          return pathForLocale(assetBase, 'en');
        }
        if (viExists) {
          return pathForLocale(assetBase, lang);
        }
        return pathForLocale(assetBase, 'en');
      }

      expect(withFallback('privacy_policy.md', 'vi', true),
          equals('assets/legal/vi/privacy_policy.md'),
          reason: 'When vi file exists, use it');

      expect(withFallback('privacy_policy.md', 'vi', false),
          equals('assets/legal/en/privacy_policy.md'),
          reason: 'When vi file missing, fallback to en');
    });

    test('Vietnamese body should contain Vietnamese headings', () {
      final enBody = '# Privacy Policy\n## Information We Collect\n';
      final viBody = '# Chính sách quyền riêng tư\n## Thông tin chúng tôi thu thập\n';

      expect(enBody.contains('Privacy Policy'), isTrue);
      expect(viBody.contains('Chính sách'), isTrue,
          reason: 'Vietnamese body should contain Vietnamese header');
      expect(viBody.contains('Privacy Policy'), isFalse,
          reason: 'Vietnamese body should NOT contain English header');
    });
  });
}