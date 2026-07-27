import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure-storage wrapper for the few credentials that need
/// platform-backed encryption (Keystore on Android, Keychain on iOS).
/// Everything else continues to live in SharedPreferences — see
/// `SecurePrefsMigration` for the strategy that picks the right sink
/// per key.
class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService _i = SecureStorageService._();
  static SecureStorageService get instance => _i;

  static const _opts = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );

  static const _iosOpts = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _opts,
    iOptions: _iosOpts,
  );

  // ─── PIN storage keys (private) ────────────────────────────────────
  static const String _kPinSalt = 'lovehub_pin_salt';
  static const String _kPinHash = 'lovehub_pin_hash';

  // ─── Generic helpers (callers choose their own keys) ───────────────
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  // ─── PIN storage ───────────────────────────────────────────────────
  Future<void> writePinSalt(String salt) =>
      _storage.write(key: _kPinSalt, value: salt);

  Future<void> writePinHash(String hash) =>
      _storage.write(key: _kPinHash, value: hash);

  Future<String?> readPinSalt() => _storage.read(key: _kPinSalt);
  Future<String?> readPinHash() => _storage.read(key: _kPinHash);

  Future<bool> containsPin() async {
    final s = await _storage.read(key: _kPinSalt);
    final h = await _storage.read(key: _kPinHash);
    return s != null && h != null;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _kPinSalt);
    await _storage.delete(key: _kPinHash);
  }

  // ─── Wipe ──────────────────────────────────────────────────────────
  Future<void> deleteAll() => _storage.deleteAll();
}
