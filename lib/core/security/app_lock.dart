import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage_service.dart';
import 'biometric_service.dart';
import 'pin_service.dart';

/// Status of the per-launch gate.
enum AppLockState {
  /// User has set neither biometric nor PIN — no gate.
  unconfigured,

  /// User opted to require biometric OR PIN at every cold start.
  enabled,

  /// Currently locked — show the unlock screen.
  locked,
}

/// Single source of truth for the app-lock gate. Drives the
/// `AppLockScreen` overlay + the biometric/PIN settings rows.
class AppLockController extends StateNotifier<AppLockState> {
  AppLockController() : super(AppLockState.locked);

  Future<void> init() async {
    final hasPin = await SecureStorageService.instance.containsPin();
    final canBiometric = await BiometricService.instance.isAvailable();
    // Biometric alone counts as "enabled"; PIN works as fallback.
    if (!hasPin && !canBiometric) {
      state = AppLockState.unconfigured;
    } else {
      state = AppLockState.locked;
    }
  }

  /// Call from the unlock screen after a successful biometric/PIN.
  void unlock() {
    if (state != AppLockState.unconfigured) {
      state = AppLockState.enabled;
    }
  }

  /// Sign-out / cold-start re-lock.
  void relock() {
    if (state == AppLockState.unconfigured) return;
    state = AppLockState.locked;
  }
}

final appLockControllerProvider =
    StateNotifierProvider<AppLockController, AppLockState>(
  (ref) => AppLockController(),
);

/// PIN hash + salt, kept here so callers don't reach into storage
/// directly.
class PinRecord {
  PinRecord({required this.salt, required this.hash});
  final String salt;
  final String hash;
}

class PinRepository {
  PinRepository._();
  static final PinRepository _i = PinRepository._();
  static PinRepository get instance => _i;

  Future<PinRecord?> read() async {
    final s = SecureStorageService.instance;
    if (!await s.containsPin()) return null;
    final salt = await s.readPinSalt();
    final hash = await s.readPinHash();
    if (salt == null || hash == null) return null;
    return PinRecord(salt: salt, hash: hash);
  }

  Future<void> write(String pin) async {
    final p = PinService.newPin(pin);
    await SecureStorageService.instance.writePinSalt(p.salt);
    await SecureStorageService.instance.writePinHash(p.hash);
  }

  Future<void> clear() async {
    await SecureStorageService.instance.clearPin();
  }
}
