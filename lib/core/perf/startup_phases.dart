import 'dart:async';
import 'package:flutter/foundation.dart';

/// Phased startup. Phase 1 runs *before* `runApp` (synchronous, must
/// finish ≤ 200 ms or the user sees a black screen). Phase 2 runs
/// *after* the first frame (deferred, can take seconds).
///
/// We split heavy inits across phases so the cold start stays under
/// the 1500 ms budget.
class StartupPhases {
  StartupPhases._();

  static final StartupPhases _instance = StartupPhases._();
  static StartupPhases get instance => _instance;

  /// Test-only factory: returns a fresh instance so test setup
  /// doesn't leak between cases.
  @visibleForTesting
  factory StartupPhases.forTest() => StartupPhases._();

  bool _phase1Complete = false;
  bool _phase2Complete = false;

  final List<Future<void> Function()> _phase1Tasks = <Future<void> Function()>[];
  final List<Future<void> Function()> _phase2Tasks = <Future<void> Function()>[];

  /// Schedule a task for phase 1 (must finish before `runApp`).
  /// If phase 1 has already completed, the task is run immediately.
  void addPhase1(Future<void> Function() task) {
    if (_phase1Complete) {
      task();
    } else {
      _phase1Tasks.add(task);
    }
  }

  /// Schedule a task for phase 2 (runs after the first frame).
  void addPhase2(Future<void> Function() task) {
    _phase2Tasks.add(task);
  }

  /// Execute every phase-1 task and return a future that resolves
  /// when they all complete (success *or* failure — failures are
  /// logged, not thrown).
  Future<void> runPhase1() async {
    await Future.wait(
      _phase1Tasks.map((t) async {
        try {
          await t();
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('[STARTUP] phase 1 task failed: $e\n$st');
          }
        }
      }),
    );
    _phase1Tasks.clear();
    _phase1Complete = true;
  }

  /// Execute every phase-2 task in a fire-and-forget manner.
  void runPhase2() {
    // Defer to the next microtask so the caller can return
    // synchronously (it's called from a PostFrameCallback).
    Future.microtask(() async {
      await Future.wait(
        _phase2Tasks.map((t) async {
          try {
            await t();
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[STARTUP] phase 2 task failed: $e');
            }
          }
        }),
      );
      _phase2Tasks.clear();
      _phase2Complete = true;
    });
  }

  bool get phase1Complete => _phase1Complete;
  bool get phase2Complete => _phase2Complete;
}