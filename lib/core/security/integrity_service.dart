import 'dart:io';
import 'package:flutter/foundation.dart';

/// Lightweight environment integrity checks. None of these are
/// bulletproof on their own — the goal is to make casual tampering
/// inconvenient (e.g. by showing a warning banner). All key business
/// actions still require server-side authorisation.
class IntegrityService {
  IntegrityService._();
  static final IntegrityService _instance = IntegrityService._();
  static IntegrityService get instance => _instance;

  static const List<String> _rootMarkers = <String>[
    '/system/xbin/su',
    '/system/bin/su',
    '/sbin/su',
    '/system/sd/xbin/su',
    '/system/app/Superuser.apk',
    '/data/local/su',
    '/system/xbin/daemonsu',
    '/system/xbin/busybox',
    '/system/xbin/ku.sud',
    '/data/adb/ksu',
    '/data/adb/magisk',
    '/sbin/magisk',
  ];

  static const List<String> _fridaMarkers = <String>[
    'frida',
    'gum-js-loop',
    'libfrida',
  ];

  /// Heuristic check for rooted / emulator / hook environment.
  IntegrityReport scan() {
    final issues = <String>[];

    if (!kReleaseMode) {
      // Don't report in debug builds — testers and devs need fun.
    }

    if (Platform.isAndroid) {
      if (_hasRootMarker()) {
        issues.add('root_detected');
      }
      if (_isEmulator()) {
        issues.add('emulator_detected');
      }
      if (_hasFridaArtifacts()) {
        issues.add('instrumented_runtime');
      }
      if (_hasDebugFlag()) {
        issues.add('debuggable_app');
      }
    }

    return IntegrityReport(
      isClean: issues.isEmpty,
      issues: issues,
      capturedAt: DateTime.now(),
    );
  }

  bool _hasRootMarker() {
    for (final p in _rootMarkers) {
      try {
        if (File(p).existsSync()) return true;
      } catch (_) {/* Permission denied → benign */}
    }
    // `which` style: if `su` is in PATH, almost certainly root.
    try {
      final r = Process.runSync('which', <String>['su']);
      if (r.exitCode == 0 && (r.stdout as String).trim().isNotEmpty) {
        return true;
      }
    } catch (_) {/* ignore */}
    return false;
  }

  bool _isEmulator() {
    final probes = <String>[];
    try {
      probes.add(Platform.environment['ANDROID_EMULATOR'] ?? '');
    } catch (_) {}
    try {
      probes.add(File('/proc/cpuinfo').readAsStringSync());
    } catch (_) {}
    final joined = probes.join('\n').toLowerCase();
    return joined.contains('goldfish') ||
        joined.contains('ranchu') ||
        joined.contains('emulator') ||
        joined.contains('qemu');
  }

  bool _hasFridaArtifacts() {
    try {
      final maps = File('/proc/self/maps').readAsStringSync();
      for (final tag in _fridaMarkers) {
        if (maps.toLowerCase().contains(tag)) return true;
      }
    } catch (_) {/* not Linux ⇒ ignore */}
    return false;
  }

  bool _hasDebugFlag() {
    // The Kotlin side can pass `am i debuggable` if we ever want a
    // server-side handshake. We default to false; if your platform
    // channels ever expose this, read it here.
    return false;
  }

  /// Allows a quick banner display without logging details off-device.
  IntegrityReport? _cached;
  IntegrityReport get cached => _cached ??= scan();
}

class IntegrityReport {
  const IntegrityReport({
    required this.isClean,
    required this.issues,
    required this.capturedAt,
  });
  final bool isClean;
  final List<String> issues;
  final DateTime capturedAt;

  @override
  String toString() => 'IntegrityReport(clean=$isClean, issues=$issues)';
}
