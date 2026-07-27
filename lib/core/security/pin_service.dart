import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// In-app PIN lock — separate from biometric so the user always has a
/// fallback if their device doesn't support biometric.
///
/// The PIN never leaves the device, and isn't stored in plaintext —
/// only its salted SHA-256 (and a verifier constant) are kept.
///
/// Key derivation:
///   hash = SHA-256( salt || utf8(pin) )
/// verifier = constant pepper || hash   (kept so brute-forcing the
/// SharedPreferences blob with a known prefix still requires the salt)
class PinService {
  PinService._();

  static const String _kVerifier = 'L0veHub:v1:pin'; // pepper prefix
  static const int _pinMinLen = 4;
  static const int _pinMaxLen = 8;

  /// Generate a fresh random salt (hex).
  static String _newSalt({int bytes = 16}) {
    final rng = Random.secure();
    final bs = List<int>.generate(bytes, (_) => rng.nextInt(256));
    return bs
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Compute the stored hash for a pin + salt.
  static String _hashOf(String pin, String salt) {
    final bytes = utf8.encode('$salt$pin');
    return sha256.convert(bytes).toString();
  }

  /// Hash to persist: `verifier || hash`. The verifier makes a stolen
  /// prefs file slightly harder to brute-force offline.
  static String _persistHash(String pin, String salt) {
    final inner = _hashOf(pin, salt);
    final outer = sha256.convert(utf8.encode('$_kVerifier$salt$inner')).toString();
    return outer;
  }

  /// Validate pin format client-side. Returns null when valid.
  static String? validatePin(String pin) {
    if (pin.length < _pinMinLen) return 'PIN too short';
    if (pin.length > _pinMaxLen) return 'PIN too long';
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      return 'PIN must be digits only';
    }
    return null;
  }

  /// Produce the (salt, hash) pair that should be written to storage
  /// for a freshly-set PIN.
  static ({String salt, String hash}) newPin(String pin) {
    if (validatePin(pin) != null) {
      throw ArgumentError('Invalid PIN');
    }
    final salt = _newSalt();
    final hash = _persistHash(pin, salt);
    return (salt: salt, hash: hash);
  }

  /// Verify a user-entered PIN against a stored (salt, hash) pair.
  static bool verify(String pin, String salt, String hash) {
    if (salt.isEmpty || hash.isEmpty) return false;
    final candidate = _persistHash(pin, salt);
    return _constantTimeEq(candidate, hash);
  }

  /// Constant-time string comparison to avoid timing oracles when we
  /// ever end up comparing hashes across the wire.
  static bool _constantTimeEq(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
