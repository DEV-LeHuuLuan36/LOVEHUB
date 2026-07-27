/// Domain interface for OneSignal push-notification operations.
///
/// Keeps the rest of the app decoupled from the OneSignal SDK and
/// from Firebase. Implementations live in `data/`.
abstract class OneSignalRepository {
  /// Initialize the OneSignal SDK. Safe to call multiple times.
  Future<void> init();

  /// Link the current device's push subscription to the user with
  /// the given Firebase [uid]. After this call, the server can
  /// target this device by `external_id == uid` via the REST API.
  Future<void> loginUser(String uid);

  /// Unlink the current device. After this call, the device falls
  /// back to an anonymous OneSignal user.
  Future<void> logout();

  /// Read the current OneSignal push subscription id (the
  /// "player id"). Returns null until the SDK has finished
  /// initializing and the user has granted push permission.
  String? get currentSubscriptionId;

  /// Request push permission from the OS. Returns true if granted.
  Future<bool> requestPermission();

  /// Register a callback invoked whenever the OneSignal push
  /// subscription id changes (e.g. after permission grant, after
  /// re-install, after `login`).
  void onSubscriptionChanged(void Function(String id) callback);
}
