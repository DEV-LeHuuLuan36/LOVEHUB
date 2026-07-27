import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Heuristics for tampering / hostile runtime. Pair with Play Integrity
/// (server-side) for definitive answers — these local checks only
/// raise warnings.
///
/// We intentionally run cheaply so the cost is paid only on
/// suspicious contexts. The full scan is opt-in via `AppStartProbe`.
class AntiTamperService {
  AntiTamperService._();
  static final AntiTamperService _instance = AntiTamperService._();
  static AntiTamperService get instance => _instance;

  /// SHA-256 of the release signing certificate. Computed once with
  /// `keytool -list -v -keystore android/app/upload-keystore.jks |
  ///  openssl sha256 -binary | base64` and pasted here.
  ///
  /// Multiple pins may be added (semicolon-separated) to support
  /// re-keying without bricking the running app.
  static const String releaseSigningHashes =
      'REPLACE_RELEASE_SHA256_HERE;BACKUP_SHA256_HERE';

  /// True if a debugger is attached (Android: `Debug.isDebuggerConnected`).
  /// Triggers every frame on debug builds, so callers must check
  /// `kReleaseMode` first.
  Future<bool> isDebuggerAttached() async {
    if (kDebugMode) return false;
    if (!Platform.isAndroid) return false;
    try {
      const channel = MethodChannel('com.lovehub/integrity');
      final result = await channel.invokeMethod<bool>('isDebuggerAttached');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// True if the running app's signing cert hash matches our known
  /// release hash. Sideloaded / re-signed APKs return false.
  Future<bool> hasReleaseSigningCert() async {
    if (kDebugMode) return true;
    if (!Platform.isAndroid) return true;
    try {
      const channel = MethodChannel('com.lovehub/integrity');
      final hash = await channel.invokeMethod<String>('signingCertHash');
      if (hash == null || hash.isEmpty) return false;
      return releaseSigningHashes.split(';').contains(hash);
    } on PlatformException {
      return false;
    }
  }

  /// True if we suspect Magisk / KernelSU / Frida / Substrate.
  /// Same heuristic as `IntegrityService` but with extra paths and
  /// the Frida `gmain` detection.
  bool hasHookingFrameworks() {
    if (!Platform.isAndroid) return false;
    final hooks = <String>[];
    try {
      final maps = File('/proc/self/maps').readAsStringSync().toLowerCase();
      for (final tag in <String>[
        'frida',
        'gmain',
        'libsubstrate',
        'libwhale',
        'libxposed',
        'gum-js-loop',
      ]) {
        if (maps.contains(tag)) hooks.add(tag);
      }
    } catch (_) {/* not Linux / permission denied */}
    return hooks.isNotEmpty;
  }

  /// True if the binary was modified (text section differs from
  /// signed APK). Only reliable in release with `android:debuggable=false`.
  Future<bool> isBinaryTampered() async {
    if (!Platform.isAndroid) return false;
    try {
      const channel = MethodChannel('com.lovehub/integrity');
      final ok = await channel.invokeMethod<bool>('verifyApkSignature');
      return !(ok ?? false);
    } on PlatformException {
      return false;
    }
  }

  /// Aggregate scan used at app start. Returns a list of issues;
  /// empty list = clean.
  Future<AntiTamperReport> scan() async {
    if (kDebugMode) {
      return const AntiTamperReport(
        issues: <String>[],
        capturedAt: null,
      );
    }
    final issues = <String>[];
    if (await isDebuggerAttached()) issues.add('debugger_attached');
    if (!await hasReleaseSigningCert()) issues.add('signature_mismatch');
    if (hasHookingFrameworks()) issues.add('hooking_framework');
    if (await isBinaryTampered()) issues.add('binary_tampered');

    return AntiTamperReport(
      issues: issues,
      capturedAt: DateTime.now(),
    );
  }
}

class AntiTamperReport {
  const AntiTamperReport({required this.issues, required this.capturedAt});
  final List<String> issues;
  final DateTime? capturedAt;

  bool get isClean => issues.isEmpty;
  bool get isHostile => issues.isNotEmpty;
}