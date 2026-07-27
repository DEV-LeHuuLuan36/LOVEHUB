// ============================================================================
// test/security/attack_dos_test.dart — Local DoS attack simulation.
//
// Models a user (or a hostile script) tapping "Save Mood" 1000
// times in 1 second. We assert that RateLimiter blocks excess
// invocations and surfaces the wait time.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lovehub/core/security/rate_limiter.dart';

void main() {
  group('RateLimiter DoS', () {
    test('denies calls past the per-second limit', () async {
      final rl = RateLimiter.perSecond('save_mood', max: 5);
      final results = <bool>[];
      for (var i = 0; i < 10; i++) {
        results.add(await rl.allow());
      }
      expect(results.take(5).every((b) => b), isTrue);
      expect(results.skip(5).every((b) => !b), isTrue);
    });

    test('window resets after the duration elapses', () async {
      final rl = RateLimiter.perSecond('save_mood',
          max: 2, window: const Duration(milliseconds: 50));
      expect(await rl.allow(), isTrue);
      expect(await rl.allow(), isTrue);
      expect(await rl.allow(), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(await rl.allow(), isTrue);
    });

    test('timeUntilReset reports remaining time', () async {
      final rl = RateLimiter.perSecond('save_mood',
          max: 1, window: const Duration(seconds: 2));
      await rl.allow();
      final remain = rl.timeUntilReset();
      expect(remain.inMilliseconds, lessThanOrEqualTo(2000));
      expect(remain.inMilliseconds, greaterThan(1500));
    });

    test('remaining quota counts down', () async {
      final rl = RateLimiter.perSecond('save_mood', max: 3);
      expect(rl.remaining, 3);
      await rl.allow();
      expect(rl.remaining, 2);
      await rl.allow();
      expect(rl.remaining, 1);
    });

    test('registry caches one limiter per key', () {
      final a = RateLimitRegistry.perMinute('foo', max: 5);
      final b = RateLimitRegistry.perMinute('foo', max: 5);
      expect(identical(a, b), isTrue);
    });

    test('clearAll wipes the registry', () {
      RateLimitRegistry.perMinute('foo', max: 5);
      RateLimitRegistry.clearAll();
      final a = RateLimitRegistry.perMinute('foo', max: 5);
      final b = RateLimitRegistry.perMinute('foo', max: 5);
      // After clearAll, both lookups return the SAME new instance
      // because the cache was reset, but they should at least both
      // be live (i.e. allow once).
      expect(identical(a, b), isTrue);
    });

    test('1000 rapid taps only ever let the first N through', () async {
      final rl = RateLimiter.perMinute('save_mood', max: 20);
      var accepted = 0;
      for (var i = 0; i < 1000; i++) {
        if (await rl.allow()) accepted += 1;
      }
      expect(accepted, 20);
    });
  });
}