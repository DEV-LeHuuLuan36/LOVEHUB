import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Thin wrapper around `local_auth` for biometric / device-credential
/// unlock. The actual PIN is stored in FlutterSecureStorage (Layer 6)
/// — this service only governs *whether* the user is allowed in.
class BiometricService {
  BiometricService._();

  static final BiometricService _instance = BiometricService._();
  static BiometricService get instance => _instance;

  final LocalAuthentication _auth = LocalAuthentication();

  /// Whether the device exposes *any* biometric OR device-credential
  /// capability that we can use.
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final supported = await _auth.getAvailableBiometrics();
      return supported.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// True iff we have at least one fingerprint, face, or iris sensor.
  Future<bool> hasBiometrics() async {
    try {
      final supported = await _auth.getAvailableBiometrics();
      const realOnes = <BiometricType>{
        BiometricType.fingerprint,
        BiometricType.face,
        BiometricType.iris,
      };
      return supported.toSet().intersection(realOnes).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Prompt the user with the system biometric / device-credential
  /// sheet. Returns true on success, false on cancel / failure.
  Future<bool> authenticate({
    String reason = 'Unlock LoveHub',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
