// ============================================================================
// test/perf/cold_start_test.dart — Cold-start budget tests.
//
// Budget (mid-range device, release build):
//   - To first frame: ≤ 1500 ms
//   - Phase 1 (blocking init): ≤ 800 ms
//   - Number of checkpoints: ≤ 10 (otherwise the trace is too noisy)
//
// These run in `flutter test` which doesn't exercise the real
// device boot path, so the assertions are structural — they
// verify the tracer wires up correctly. Real budget validation
// happens via `flutter run --profile` + DevTools.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lovehub/core/perf/cold_start_tracer.dart';
import 'package:lovehub/core/perf/startup_phases.dart';

void main() {
  // Reset the global state between tests.
  setUp(() {
    // The ColdStartTracer is a process-wide singleton; we
    // tolerate leftover checkpoints from earlier tests but
    // assert the order is sane.
  });

  group('ColdStartTracer', () {
    test('records checkpoints in order', () {
      final t = ColdStartTracer.instance;
      final initial = t.checkpoints.length;
      t.mark('test_a');
      t.mark('test_b');
      final after = t.checkpoints;
      expect(after.length - initial, greaterThanOrEqualTo(2));
      final lastTwo = after.sublist(after.length - 2);
      expect(lastTwo.first.label, 'test_a');
      expect(lastTwo.last.label, 'test_b');
    });

    test('dump() includes all checkpoints + longest gap', () {
      final t = ColdStartTracer.instance;
      t.mark('alpha');
      // Insert a tiny delay to ensure a measurable gap.
      Future<void>.delayed(const Duration(milliseconds: 2), () {
        t.mark('beta');
      });
      return Future<void>.delayed(const Duration(milliseconds: 5), () {
        final dump = t.dump();
        expect(dump, contains('Cold-start trace'));
        expect(dump, contains('alpha'));
        expect(dump, contains('beta'));
      });
    });

    test('longestGap returns null for < 2 checkpoints', () {
      final t = ColdStartTracer.instance;
      // Even after a reset the instance has the early checkpoints.
      // We can't easily reset the global, so this test asserts the
      // call returns either null or a (from, to, ms) record.
      final gap = t.longestGap();
      if (t.checkpoints.length < 2) {
        expect(gap, isNull);
      } else {
        expect(gap, isNotNull);
      }
    });
  });

  group('StartupPhases', () {
    test('phase-1 task runs before phase-2 task', () async {
      final order = <String>[];
      final phases = StartupPhases.forTest();
      phases
        ..addPhase1(() async {
          order.add('phase1');
        })
        ..addPhase2(() async {
          order.add('phase2');
        });
      await phases.runPhase1();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      phases.runPhase2();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(order, ['phase1', 'phase2']);
    });

    test('phase-1 task added after runPhase1 still executes', () async {
      final phases = StartupPhases.forTest();
      await phases.runPhase1();
      var ran = false;
      phases.addPhase1(() async {
        ran = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(ran, isTrue);
    });

    test('phase-2 task failure does not block other phase-2 tasks', () async {
      final phases = StartupPhases.forTest();
      var secondRan = false;
      phases
        ..addPhase2(() async {
          throw StateError('boom');
        })
        ..addPhase2(() async {
          secondRan = true;
        });
      phases.runPhase2();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(secondRan, isTrue);
    });
  });
}
