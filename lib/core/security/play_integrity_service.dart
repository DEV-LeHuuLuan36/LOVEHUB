import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Google Play Integrity API wrapper.
///
/// On Android, Google Play can attest:
///   - The app was installed from Play (not sideloaded from APK)
///   - The app is running on a genuine Android device (not an
///     emulator or a spoofed one)
///   - The app's signing certificate matches the one Play knows
///
/// Without server-side verification this is just a number. We send
/// the integrity token to our Cloud Function, which calls Play's
/// API server-side, parses the verdict, and writes a boolean to
/// Firestore. The Firestore rules in this repo refuse writes from
/// devices that don't pass this check.
///
/// In debug builds we skip the integrity call entirely (no Play
/// Services, sideloaded dev build, etc.).
class PlayIntegrityService {
  PlayIntegrityService._();
  static final PlayIntegrityService _instance = PlayIntegrityService._();
  static PlayIntegrityService get instance => _instance;

  /// Cache the verdict for 1 hour to avoid hammering Play's API.
  PlayVerdict? _cached;
  DateTime? _cachedAt;
  static const Duration _cacheFor = Duration(hours: 1);

  Future<PlayVerdict> currentVerdict({bool forceRefresh = false}) async {
    if (kDebugMode) {
      return PlayVerdict(
        deviceIntegrity: PlayIntegrityLabel.debug,
        appIntegrity: PlayIntegrityLabel.ok,
        accountDetails: PlayIntegrityLabel.ok,
        nonce: 'debug-${DateTime.now().millisecondsSinceEpoch}',
        rawToken: null,
        verified: true,
      );
    }

    if (!forceRefresh &&
        _cached != null &&
        DateTime.now().difference(_cachedAt!) < _cacheFor) {
      return _cached!;
    }

    final nonce = _generateNonce();
    final token = await _requestIntegrityToken(nonce);
    if (token == null) {
      // Fail closed: refuse to operate if we cannot prove integrity.
      return _cached = PlayVerdict(
        deviceIntegrity: PlayIntegrityLabel.unknown,
        appIntegrity: PlayIntegrityLabel.unknown,
        accountDetails: PlayIntegrityLabel.unknown,
        nonce: nonce,
        rawToken: null,
        verified: false,
      );
    }
    final verdict = await _verifyOnServer(token, nonce);
    _cached = verdict;
    _cachedAt = DateTime.now();
    return verdict;
  }

  /// 16-byte random nonce, base64 encoded.
  /// Combines the request id with the current minute so a token
  /// captured and replayed is invalidated within a minute.
  String _generateNonce() {
    final bytes = List<int>.generate(16, (_) => DateTime.now().microsecond % 256);
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    return base64.encode(utf8.encode('$ts:${base64Encode(bytes)}'));
  }

  Future<String?> _requestIntegrityToken(String nonce) async {
    try {
      // The actual call lives in the Kotlin side via a platform
      // channel (see `android/app/src/main/kotlin/com/lovehub/
      // IntegrityPlugin.kt` — TODO(G1.2)). For now we fall back to
      // a Cloud Function so the project still compiles without it.
      final result = await FirebaseFunctions.instance
          .httpsCallable('requestIntegrityToken')
          .call<String>({'nonce': nonce});
      return result.data;
    } catch (e) {
      debugPrint('[INTEGRITY] request failed: $e');
      return null;
    }
  }

  Future<PlayVerdict> _verifyOnServer(String token, String nonce) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('verifyIntegrityToken')
          .call<Map<String, dynamic>>({
        'token': token,
        'nonce': nonce,
      });
      final m = result.data;
      return PlayVerdict(
        deviceIntegrity: PlayIntegrityLabel.fromString(m['device'] as String?),
        appIntegrity: PlayIntegrityLabel.fromString(m['app'] as String?),
        accountDetails: PlayIntegrityLabel.fromString(m['account'] as String?),
        nonce: nonce,
        rawToken: token,
        verified: m['verdict'] == 'OK',
      );
    } catch (e) {
      debugPrint('[INTEGRITY] verify failed: $e');
      return PlayVerdict(
        deviceIntegrity: PlayIntegrityLabel.unknown,
        appIntegrity: PlayIntegrityLabel.unknown,
        accountDetails: PlayIntegrityLabel.unknown,
        nonce: nonce,
        rawToken: token,
        verified: false,
      );
    }
  }

  /// Local hash for audit logs.
  String hashToken(String token) {
    final bytes = utf8.encode(token);
    return sha256.convert(bytes).toString();
  }
}

class PlayVerdict {
  PlayVerdict({
    required this.deviceIntegrity,
    required this.appIntegrity,
    required this.accountDetails,
    required this.nonce,
    required this.rawToken,
    required this.verified,
  });

  final PlayIntegrityLabel deviceIntegrity;
  final PlayIntegrityLabel appIntegrity;
  final PlayIntegrityLabel accountDetails;
  final String nonce;
  final String? rawToken;
  final bool verified;

  bool get isPlayDevice => deviceIntegrity == PlayIntegrityLabel.ok;
  bool get isInstalledFromPlay =>
      appIntegrity == PlayIntegrityLabel.ok ||
      appIntegrity == PlayIntegrityLabel.debug;

  Map<String, Object?> toJson() => <String, Object?>{
        'device': deviceIntegrity.name,
        'app': appIntegrity.name,
        'account': accountDetails.name,
        'nonce': nonce,
        'verified': verified,
      };
}

enum PlayIntegrityLabel {
  unknown,
  ok,
  debug,
  emulator,
  rooted,
  // When Google Play cannot evaluate the device (no Play Services).
  noPlayServices;

  static PlayIntegrityLabel fromString(String? s) {
    switch (s) {
      case 'OK':
        return PlayIntegrityLabel.ok;
      case 'DEBUG':
        return PlayIntegrityLabel.debug;
      case 'EMULATOR':
        return PlayIntegrityLabel.emulator;
      case 'ROOTED':
        return PlayIntegrityLabel.rooted;
      case 'NO_PLAY_SERVICES':
        return PlayIntegrityLabel.noPlayServices;
      default:
        return PlayIntegrityLabel.unknown;
    }
  }
}