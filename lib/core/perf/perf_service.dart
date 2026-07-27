import 'package:flutter/foundation.dart';

/// Performance monitoring stub.
///
/// In this stub version, all methods are no-ops so the app builds
/// without requiring the firebase_performance package to be fully
/// wired. To enable real Firebase Performance monitoring:
///
///   1. Run: flutter pub add firebase_performance
///   2. Uncomment the real implementation below
///   3. Import `package:firebase_performance/firebase_performance.dart`
///
/// Until then, cold-start and frame metrics are still tracked locally
/// via ColdStartTracer and JankWatch (console output only).
class PerfService {
  PerfService._();
  static final PerfService _instance = PerfService._();
  static PerfService get instance => _instance;

  /// Log a named operation start. Returns a handle — call [stop] when done.
  /// In stub mode: logs to console in debug builds.
  void startOperation(String name) {
    if (kDebugMode) {
      debugPrint('[PERF] start: $name');
    }
  }

  /// End a named operation and record its duration.
  void endOperation(String name) {
    if (kDebugMode) {
      debugPrint('[PERF] end: $name');
    }
  }

  /// Record a custom integer metric (e.g. cold_start_gap_ms, pet_hp).
  /// In stub mode: logs to console.
  void recordMetric(String name, int value) {
    if (kDebugMode) {
      debugPrint('[PERF] metric $name=$value');
    }
  }
}
