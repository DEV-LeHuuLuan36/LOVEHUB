import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Per-request nonce + timestamp used to defeat replay attacks.
///
/// Flow:
///   1. Caller builds a [ReplayGuard] with action + payload.
///   2. The guard signs (timestamp || nonce || payload) with a
///      per-session HMAC key.
///   3. Server receives { timestamp, nonce, signature, payload }
///      and rejects if:
///        - timestamp drift > 60s
///        - nonce already seen (cached for 5 min)
///        - signature doesn't match
///
/// We use HMAC-SHA-256 with a session-scoped key (random per
/// login) so a leaked signature from one request doesn't enable
/// replays of others.
class ReplayGuard {
  ReplayGuard({
    required this.action,
    required this.payload,
    required this.sessionKey,
    DateTime? now,
    Random? rng,
  })  : _now = now ?? DateTime.now(),
        _rng = rng ?? Random.secure();

  final String action;
  final Map<String, Object?> payload;
  final String sessionKey;
  final DateTime _now;
  final Random _rng;

  static const Duration maxDrift = Duration(seconds: 60);
  static const Duration nonceCache = Duration(minutes: 5);

  /// Serialised wire format: JSON object with all 4 fields.
  Map<String, Object?> toJson() {
    final nonce = _nonce();
    final sig = _sign(nonce);
    return <String, Object?>{
      'action': action,
      'ts': _now.millisecondsSinceEpoch,
      'nonce': nonce,
      'payload': payload,
      'sig': sig,
    };
  }

  String _nonce() {
    // 12 bytes (96 bits) of entropy is more than enough for replay
    // protection; we burn it in the server's nonce cache.
    final bytes = List<int>.generate(12, (_) => _rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _sign(String nonce) {
    final message = '${_now.millisecondsSinceEpoch}'
        '|$nonce|${_canonicalJson(payload)}';
    final hmac = Hmac(sha256, utf8.encode(sessionKey));
    return base64Url.encode(hmac.convert(utf8.encode(message)).bytes);
  }
}

/// Recursive JSON encode with sorted object keys. Used to make
/// signatures stable across re-orderings of the payload map.
String _canonicalJson(Object? value) {
  if (value is Map) {
    final sorted = value.keys.cast<String>().toList()..sort();
    final entries = sorted
        .map((k) => '"${_escape(k)}":${_canonicalJson(value[k])}')
        .join(',');
    return '{$entries}';
  }
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value is String) return '"${_escape(value)}"';
  if (value is num || value is bool) return '$value';
  return 'null';
}

String _escape(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll(r'"', r'\"');

/// Verify a replay-guarded request server-side (called from a Cloud
/// Function). Returns null on success, error string otherwise.
String? verifyReplayGuard(Map<String, Object?> body, String sessionKey) {
  final ts = body['ts'] as int?;
  final nonce = body['nonce'] as String?;
  final sig = body['sig'] as String?;
  final payload = body['payload'] as Map<String, Object?>? ?? <String, Object?>{};
  if (ts == null || nonce == null || sig == null) {
    return 'missing_field';
  }
  final drift = (DateTime.now().millisecondsSinceEpoch - ts).abs();
  if (drift > ReplayGuard.maxDrift.inMilliseconds) {
    return 'drift_too_large';
  }
  final expected = base64Url.encode(
    Hmac(sha256, utf8.encode(sessionKey))
        .convert(utf8.encode('$ts|$nonce|${_canonicalJson(payload)}'))
        .bytes,
  );
  if (expected != sig) {
    return 'bad_signature';
  }
  return null; // Nonce cache check happens server-side.
}