import 'dart:async';
import 'package:flutter/foundation.dart';

/// Per-key token-bucket rate limiter for in-app actions (e.g. "user
/// tapped Save 30 times in 2 seconds"). Firestore server-side rate
/// limits are enforced via Security Rules for cross-device abuse; this
/// is purely a local UX guard so a stuck button can't drain the
/// battery or pollute analytics.
///
/// Usage:
///   final rl = RateLimiter.perMinute('save_mood', max: 5);
///   if (await rl.allow()) { ... }
class RateLimiter {
  RateLimiter._(this.key, {required this.max, required this.window});
  factory RateLimiter.perMinute(String key, {int max = 10}) =>
      RateLimiter._(key, max: max, window: const Duration(minutes: 1));
  factory RateLimiter.perHour(String key, {int max = 100}) =>
      RateLimiter._(key, max: max, window: const Duration(hours: 1));
  factory RateLimiter.perSecond(String key, {int max = 1, Duration window = const Duration(seconds: 1)}) =>
      RateLimiter._(key, max: max, window: window);

  final String key;
  final int max;
  final Duration window;

  /// Number of accepted calls in the current window.
  int _count = 0;
  DateTime _windowStart = DateTime.now();
  final Map<String, int> _awaited = <String, int>{};

  /// Returns true if the action is allowed right now, false otherwise.
  /// Resets the window counter when the window has elapsed.
  Future<bool> allow() async {
    final now = DateTime.now();
    if (now.difference(_windowStart) >= window) {
      _windowStart = now;
      _count = 0;
    }
    if (_count >= max) {
      _awaited[key] = (_awaited[key] ?? 0) + 1;
      debugPrint('[RATE] $key hit limit ($max / $window)');
      return false;
    }
    _count += 1;
    return true;
  }

  /// How long the caller should wait before retrying.
  Duration timeUntilReset() {
    final elapsed = DateTime.now().difference(_windowStart);
    final remain = window - elapsed;
    return remain.isNegative ? Duration.zero : remain;
  }

  /// Remaining quota inside the current window.
  int get remaining {
    final now = DateTime.now();
    if (now.difference(_windowStart) >= window) return max;
    return (max - _count).clamp(0, max);
  }

  /// Total number of times we have denied a caller.
  int get timesDenied => _awaited[key] ?? 0;
}

/// Singleton registry — limiters are expensive so we cache them by key.
class RateLimitRegistry {
  RateLimitRegistry._();
  static final Map<String, RateLimiter> _registry = <String, RateLimiter>{};

  static RateLimiter perMinute(String key, {int max = 10}) {
    final k = '$key/min/$max';
    return _registry.putIfAbsent(
      k, () => RateLimiter.perMinute(key, max: max),
    );
  }

  static RateLimiter perHour(String key, {int max = 100}) {
    final k = '$key/hr/$max';
    return _registry.putIfAbsent(
      k, () => RateLimiter.perHour(key, max: max),
    );
  }

  static RateLimiter perSecond(
    String key, {
    int max = 1,
    Duration window = const Duration(seconds: 1),
  }) {
    final k = '$key/sec/$max/$window.inMilliseconds';
    return _registry.putIfAbsent(
      k, () => RateLimiter.perSecond(key, max: max, window: window),
    );
  }

  /// Drop all cached limiters (call after sign-out / re-auth).
  static void clearAll() => _registry.clear();
}
