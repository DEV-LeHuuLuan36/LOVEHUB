import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Watches the frame timing during scroll / animation-heavy
/// interactions. Fires a callback whenever a frame exceeds the
/// budget (16 ms for 60 fps, 8 ms for 120 fps).
///
/// Use:
///   final watch = JankWatch(binding: SchedulerBinding.instance);
///   watch.start();
///   // ... interact
///   watch.stop();
///
/// In production we wire this to:
///   - the audit logger (write a 'jank' event with offending ms)
///   - Crashlytics breadcrumb
class JankWatch {
  JankWatch({SchedulerBinding? binding})
      : _binding = binding ?? SchedulerBinding.instance;

  final SchedulerBinding _binding;

  final List<int> _frameTimesMs = <int>[];
  bool _active = false;

  /// 16 ms = 60 fps. Anything over is "jank".
  static const int budgetMs = 16;
  static const int hardBudgetMs = 100; // truly catastrophic

  /// Optional override. Set to 8 for 120 Hz panels.
  final int budget = budgetMs;

  void start() {
    if (_active) return;
    _active = true;
    _frameTimesMs.clear();
    _binding.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_active) return;
    _active = false;
    _binding.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final buildMs = (t.buildDuration.inMicroseconds / 1000).round();
      final rasterMs = (t.rasterDuration.inMicroseconds / 1000).round();
      final total = buildMs + rasterMs;
      _frameTimesMs.add(total);
      if (total > hardBudgetMs) {
        debugPrint('[JANK] catastrophic: ${total}ms (build=$buildMs raster=$rasterMs)');
      } else if (total > budget) {
        debugPrint('[JANK] over budget: ${total}ms (build=$buildMs raster=$rasterMs)');
      }
    }
  }

  /// 95th percentile of frame times in ms. Aim for ≤ 16.
  int p95Ms() {
    if (_frameTimesMs.isEmpty) return 0;
    final sorted = List<int>.from(_frameTimesMs)..sort();
    final idx = (sorted.length * 0.95).floor().clamp(0, sorted.length - 1);
    return sorted[idx];
  }

  /// Slowest frame time observed.
  int maxMs() {
    if (_frameTimesMs.isEmpty) return 0;
    return _frameTimesMs.reduce((a, b) => a > b ? a : b);
  }

  /// Frames over budget, as a percentage.
  double jankyFramePct() {
    if (_frameTimesMs.isEmpty) return 0;
    final over = _frameTimesMs.where((t) => t > budget).length;
    return over * 100.0 / _frameTimesMs.length;
  }

  /// Snapshot of the current run. Returns null when [start] was
  /// never called.
  JankReport? snapshot() {
    if (_frameTimesMs.isEmpty) return null;
    return JankReport(
      frameCount: _frameTimesMs.length,
      p95Ms: p95Ms(),
      maxMs: maxMs(),
      jankyPct: jankyFramePct(),
    );
  }
}

class JankReport {
  const JankReport({
    required this.frameCount,
    required this.p95Ms,
    required this.maxMs,
    required this.jankyPct,
  });
  final int frameCount;
  final int p95Ms;
  final int maxMs;
  final double jankyPct;

  /// False when the run was clean enough for 60 fps.
  bool get isHealthy => p95Ms <= 16 && jankyPct < 5;

  @override
  String toString() =>
      'JankReport(frames=$frameCount, p95=${p95Ms}ms, max=${maxMs}ms, '
      'janky=${jankyPct.toStringAsFixed(1)}%)';
}