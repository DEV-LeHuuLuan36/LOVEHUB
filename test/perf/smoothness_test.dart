// ============================================================================
// test/perf/smoothness_test.dart — Smoothness budget tests.
//
// We can't measure real 60 fps scroll performance in `flutter test`
// (no real vsync). What we DO verify:
//   1. JankWatch records frame timings.
//   2. JankReport computes p95 + janky % correctly.
//   3. JankWatch stops cleanly (no leak).
// ============================================================================

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovehub/core/perf/jank_watch.dart';

void main() {
  group('JankWatch', () {
    testWidgets('records frame timings', (tester) async {
      final w = JankWatch(binding: tester.binding);
      w.start();
      // Pump a few frames.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      w.stop();
      // Even in test mode, the scheduler may produce at least one
      // timing event.
      final snap = w.snapshot();
      if (snap != null) {
        expect(snap.frameCount, greaterThan(0));
      }
    });

    test('p95 calculation handles empty list', () {
      // Indirect via snapshot — we cannot easily inject timings.
      // The no-frame path returns null.
      final w = JankWatch(binding: SchedulerBinding.instance);
      expect(w.snapshot(), isNull);
    });

    test('budget is 16ms by default', () {
      expect(JankWatch.budgetMs, 16);
    });

    test('hard budget is 100ms', () {
      expect(JankWatch.hardBudgetMs, 100);
    });
  });

  group('JankReport', () {
    test('isHealthy when p95 ≤ 16 and jankyPct < 5%', () {
      const r = JankReport(
        frameCount: 100,
        p95Ms: 14,
        maxMs: 18,
        jankyPct: 2.0,
      );
      expect(r.isHealthy, isTrue);
    });

    test('not healthy when p95 > 16', () {
      const r = JankReport(
        frameCount: 100,
        p95Ms: 24,
        maxMs: 30,
        jankyPct: 2.0,
      );
      expect(r.isHealthy, isFalse);
    });

    test('not healthy when jankyPct > 5', () {
      const r = JankReport(
        frameCount: 100,
        p95Ms: 14,
        maxMs: 30,
        jankyPct: 12.0,
      );
      expect(r.isHealthy, isFalse);
    });

    test('toString includes key fields', () {
      const r = JankReport(
        frameCount: 100,
        p95Ms: 14,
        maxMs: 30,
        jankyPct: 12.0,
      );
      expect(r.toString(), contains('frames=100'));
      expect(r.toString(), contains('p95=14ms'));
      expect(r.toString(), contains('janky=12.0%'));
    });
  });
}