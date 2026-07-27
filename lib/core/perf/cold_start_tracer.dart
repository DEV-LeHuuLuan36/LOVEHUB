import 'package:flutter/foundation.dart';

/// Tracks cold-start timing so we can alert when we blow the budget.
///
/// Budget:
///   - To first frame (TTI): ≤ 1500 ms on a mid-range device
///   - To first paint of splash: ≤ 200 ms
///   - First screen content visible: ≤ 1500 ms
///
/// All numbers are measured in milliseconds since `runApp()`. We
/// fire `debugPrint` lines tagged [COLD-START] so they can be
/// grep'd from logcat when triaging a regression.
class ColdStartTracer {
  ColdStartTracer._();
  static final ColdStartTracer _instance = ColdStartTracer._();
  static ColdStartTracer get instance => _instance;

  final Stopwatch _stopwatch = Stopwatch()..start();
  final List<Checkpoint> _checkpoints = <Checkpoint>[];

  void mark(String label) {
    if (!kDebugMode && !kProfileMode) return;
    _checkpoints.add(Checkpoint(label, _stopwatch.elapsedMilliseconds));
    debugPrint('[COLD-START] +${_stopwatch.elapsedMilliseconds}ms $label');
  }

  List<Checkpoint> get checkpoints => List.unmodifiable(_checkpoints);

  /// Returns the longest gap in the trace — usually the one to
  /// optimise.
  ({String from, String to, int ms})? longestGap() {
    if (_checkpoints.length < 2) return null;
    int bestMs = -1;
    int bestFrom = -1;
    for (var i = 1; i < _checkpoints.length; i++) {
      final gap = _checkpoints[i].ms - _checkpoints[i - 1].ms;
      if (gap > bestMs) {
        bestMs = gap;
        bestFrom = i - 1;
      }
    }
    return (
      from: _checkpoints[bestFrom].label,
      to: _checkpoints[bestFrom + 1].label,
      ms: bestMs,
    );
  }

  /// Pretty-print the trace. Useful for unit tests / golden runs.
  String dump() {
    final buf = StringBuffer('Cold-start trace (ms):\n');
    for (final c in _checkpoints) {
      buf.writeln('  +${c.ms.toString().padLeft(5)}  ${c.label}');
    }
    final gap = longestGap();
    if (gap != null) {
      buf.writeln('Biggest gap: ${gap.from} → ${gap.to} = ${gap.ms} ms');
    }
    return buf.toString();
  }
}

class Checkpoint {
  Checkpoint(this.label, this.ms);
  final String label;
  final int ms;
}