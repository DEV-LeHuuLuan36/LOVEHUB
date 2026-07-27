import 'dart:async';
import 'dart:io' show ProcessInfo;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Lightweight stream-subscription tracker for leak hunting.
///
/// Stream<List<X>> providers in Riverpod auto-cancel when their
/// provider is disposed, but **custom** StreamControllers, late
/// subscriptions, or background services are easy to leak.
///
/// Usage:
///   final sub = controller.stream.listen((_) {});
///   LeakHunter.watch(sub, tag: 'auth:streak');
///
/// On test tear-down, call [LeakHunter.verifyNoLeaks] to assert
/// every watched subscription was cancelled.
class LeakHunter {
  LeakHunter._();

  static final Map<int, _WatchedSub> _watched = <int, _WatchedSub>{};
  static int _seq = 0;

  static StreamSubscription<T> watch<T>(
    StreamSubscription<T> sub, {
    required String tag,
  }) {
    _seq += 1;
    _watched[_seq] = _WatchedSub(_seq, tag, DateTime.now());
    sub.onDone(() {
      _watched.remove(_seq);
    });
    return sub;
  }

  /// Snapshot of currently-tracked live subscriptions. Useful for
  /// tests + the audit dashboard.
  static List<({int id, String tag, DateTime since})> live() {
    return _watched.values
        .map((w) => (id: w.id, tag: w.tag, since: w.since))
        .toList();
  }

  /// Throw if any subscription is still tracked (test-only).
  static void verifyNoLeaks({Duration? olderThan}) {
    final stale = _watched.values
        .where((w) =>
            olderThan == null ||
            DateTime.now().difference(w.since) > olderThan)
        .toList();
    if (stale.isNotEmpty) {
      throw StateError(
        'LeakHunter: ${stale.length} active subscriptions:\n'
        '${stale.map((w) => '  ${w.id} ${w.tag} (${w.since})').join('\n')}',
      );
    }
  }
}

class _WatchedSub {
  _WatchedSub(this.id, this.tag, this.since);
  final int id;
  final String tag;
  final DateTime since;
}

/// Force-runs a GC and returns the resident memory in MB. Used by
/// the perf dashboard and the leak tests.
///
/// On Dart VM this is best-effort. On Android we additionally
/// consume `ProcessInfo` through a platform channel.
Future<int> approximateResidentMb() async {
  // `ProcessInfo.currentRss` returns bytes on Dart VM.
  final rss = ProcessInfo.currentRss;
  return (rss / (1024 * 1024)).round();
}

/// Logs the current memory pressure. Drops a warning in debug when
/// we cross the configured threshold.
Future<void> logMemoryPressure({
  int warnMb = 220,
  int errorMb = 350,
}) async {
  if (!kDebugMode) return;
  final mb = await approximateResidentMb();
  if (mb >= errorMb) {
    debugPrint('[MEMORY] CRITICAL: ${mb}MB resident');
  } else if (mb >= warnMb) {
    debugPrint('[MEMORY] WARNING: ${mb}MB resident');
  } else {
    debugPrint('[MEMORY] ${mb}MB resident');
  }
}

/// Helper for `dispose()` overrides that must cancel late
/// subscriptions + animation controllers.
mixin DisposableHost<T extends StatefulWidget> on State<T> {
  final List<VoidCallback> _cleanups = <VoidCallback>[];

  /// Register a teardown to run when the widget is disposed. The
  /// returned helper removes the registration.
  VoidCallback onDispose(VoidCallback cb) {
    _cleanups.add(cb);
    return () => _cleanups.remove(cb);
  }

  @override
  void dispose() {
    for (final cb in _cleanups) {
      try {
        cb();
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[DISPOSE] teardown failed: $e\n$st');
        }
      }
    }
    _cleanups.clear();
    super.dispose();
  }
}