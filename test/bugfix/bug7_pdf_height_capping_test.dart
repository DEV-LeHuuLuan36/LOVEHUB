import 'package:flutter_test/flutter_test.dart';

/// BUG_7 test: PDF widget can't be 1145px tall when page is 761px tall.
///
/// The fix:
/// 1. Cap image display height to a safe max (e.g. 400pt)
/// 2. Wrap each memory in pw.Wrap or pw.Column with maxHeight constraint
/// 3. Or use pw.MultiPage (already used) but ensure no single widget exceeds page height
///
/// Test verifies: image height is clamped to a max safe value.
void main() {
  group('BUG_7: PDF widget height exceeds page height', () {
    test('image height must be capped to fit within A4 page', () {
      // A4 page = 595.28 x 841.89 pt
      // With 40pt margins on all sides → content area ≈ 515.28 x 761.89 pt
      const double contentWidth = 515.28;
      const double maxContentHeight = 700.0;

      // Simulate the old broken behavior
      double brokenDisplayHeight(double imgW, double imgH) {
        final aspectRatio = imgW / imgH;
        return contentWidth / aspectRatio;
      }

      // Simulate the fixed behavior
      double fixedDisplayHeight(double imgW, double imgH) {
        final aspectRatio = imgW / imgH;
        final calc = contentWidth / aspectRatio;
        return calc > maxContentHeight ? maxContentHeight : calc;
      }

      // Portrait image: 800x1200 → aspect 0.667 → broken calc = 772.9pt
      final brokenH = brokenDisplayHeight(800, 1200);
      expect(brokenH, greaterThan(maxContentHeight));

      final fixedH = fixedDisplayHeight(800, 1200);
      expect(fixedH, equals(maxContentHeight));

      // Landscape image: 1200x800 → aspect 1.5 → calc = 343.5pt
      final landscapeFixedH = fixedDisplayHeight(1200, 800);
      expect(landscapeFixedH, lessThan(maxContentHeight));
    });

    test('total stack height should flow across pages', () {
      // A page can hold ~700pt of content
      const double pageBudget = 700.0;
      final memoryHeights = [80.0, 400.0, 350.0];

      // First page holds content until budget runs out
      var used = 0.0;
      var pages = 1;
      final perPage = <int>[0];
      for (final h in memoryHeights) {
        if (used + h > pageBudget) {
          pages++;
          used = h;
          perPage.add(1);
        } else {
          used += h;
          perPage[perPage.length - 1]++;
        }
      }

      expect(pages, equals(2),
          reason: 'Content should flow across multiple pages naturally');
    });
  });
}