import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../../../config/api_config.dart';

/// Thin wrapper around the [OneSignal] static API.
///
/// This is the data source for OneSignal operations. It is a
/// singleton because the native SDK is itself a singleton; multiple
/// Dart-side instances would share state. The repository layer
/// (`OneSignalRepositoryImpl`) wraps this in a domain interface.
class OneSignalService {
  OneSignalService._();

  static final OneSignalService _instance = OneSignalService._();
  factory OneSignalService() => _instance;

  bool _initialized = false;

  /// Most recent push subscription id ("player id") we observed.
  /// Read via [currentSubscriptionId]. Cached because
  /// `OneSignal.User.pushSubscription.id` may briefly return null
  /// right after init; the subscription observer is the
  /// recommended reliable source.
  String? _lastSubscriptionId;

  String? get currentSubscriptionId =>
      _lastSubscriptionId ?? OneSignal.User.pushSubscription.id;

  /// Initialize the OneSignal SDK. Safe to call multiple times.
  void init() {
    if (_initialized) return;
    _initialized = true;

    final appId = ApiConfig.oneSignalAppId;
    debugPrint(
      'ONESIGNAL_DBG: OneSignal.initialize() about to run, '
      'appId="${appId}", length=${appId.length}, '
      'startsWithUUID=${_looksLikeUuid(appId)}',
    );
    if (appId.isEmpty) {
      debugPrint(
        'ONESIGNAL_DBG: ABORT — appId is empty. Check '
        'lib/core/config/onesignal_config.dart (and .gitignore).',
      );
      return;
    }
    try {
      OneSignal.initialize(appId);
      debugPrint('ONESIGNAL_DBG: OneSignal.initialize() returned');
    } catch (e, st) {
      debugPrint('ONESIGNAL_DBG: OneSignal.initialize() THREW: $e\n$st');
      return;
    }

    // Observe push-subscription changes. This is the recommended
    // way to read `OneSignal.User.pushSubscription.id` reliably —
    // it may be null right after initialize() and only become
    // available via this observer.
    OneSignal.User.pushSubscription.addObserver(_onPushSubscriptionChange);
    debugPrint('ONESIGNAL_DBG: push-subscription observer registered');

    // Pre-seed from the SDK's current value in case the observer
    // fires before any consumer subscribes.
    final initialId = OneSignal.User.pushSubscription.id;
    final initialOptedIn = OneSignal.User.pushSubscription.optedIn;
    debugPrint(
      'ONESIGNAL_DBG: post-init subscription state — '
      'id=$initialId, optedIn=$initialOptedIn',
    );
    if (initialId != null) _lastSubscriptionId = initialId;
  }

  static bool _looksLikeUuid(String s) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(s);
  }

  /// Internal observer passed to the OneSignal SDK. The v5.x API
  /// exposes this as a `typedef`, so we just supply a function.
  void _onPushSubscriptionChange(
    OSPushSubscriptionChangedState stateChanges,
  ) {
    final id = stateChanges.current.id;
    final optedIn = stateChanges.current.optedIn;
    debugPrint(
      'ONESIGNAL_DBG: push-subscription change — id=$id, optedIn=$optedIn',
    );
    if (id == null || id.isEmpty) return;
    _lastSubscriptionId = id;
    for (final cb in _subscriptionCallbacks) {
      cb(id);
    }
  }

  final List<void Function(String id)> _subscriptionCallbacks = [];

  /// Register a callback invoked whenever the push subscription id
  /// changes (after permission grant, after re-install, after
  /// login). Fires immediately with the current value if known.
  void onSubscriptionChanged(void Function(String id) callback) {
    _subscriptionCallbacks.add(callback);
    final current = currentSubscriptionId;
    if (current != null) callback(current);
  }

  /// Request push permission from the OS. Returns true if granted.
  /// `fallbackToSettings = true` sends the user to system settings
  /// if they've permanently denied the prompt before.
  Future<bool> requestPermission() async {
    debugPrint(
      'ONESIGNAL_DBG: OneSignal.Notifications.requestPermission(true) called',
    );
    try {
      final granted = await OneSignal.Notifications.requestPermission(true);
      debugPrint(
        'ONESIGNAL_DBG: requestPermission returned granted=$granted, '
        'sdk-permission=${OneSignal.Notifications.permission}',
      );
      // Log the subscription id again — granting permission may
      // synchronously generate a fresh push subscription.
      final id = OneSignal.User.pushSubscription.id;
      final optedIn = OneSignal.User.pushSubscription.optedIn;
      debugPrint(
        'ONESIGNAL_DBG: post-requestPermission subscription — '
        'id=$id, optedIn=$optedIn',
      );
      if (id != null && id.isNotEmpty) _lastSubscriptionId = id;
      return granted;
    } catch (e, st) {
      debugPrint('ONESIGNAL_DBG: requestPermission THREW: $e\n$st');
      return false;
    }
  }

  /// Link the current device to a known user via OneSignal's
  /// external-id system. After this call, the server (the
  /// Cloudflare Worker) can target this device by
  /// `external_id == uid` via the REST API.
  Future<void> loginUser(String uid) async {
    debugPrint('ONESIGNAL_DBG: OneSignal.login(uid=$uid) called');
    try {
      await OneSignal.login(uid);
      debugPrint('ONESIGNAL_DBG: OneSignal.login() returned');
    } catch (e, st) {
      debugPrint('ONESIGNAL_DBG: OneSignal.login() THREW: $e\n$st');
      rethrow;
    }
  }

  /// Unlink the current device. The device falls back to an
  /// anonymous OneSignal user.
  Future<void> logout() async {
    debugPrint('ONESIGNAL_DBG: OneSignal.logout() called');
    try {
      await OneSignal.logout();
      debugPrint('ONESIGNAL_DBG: OneSignal.logout() returned');
    } catch (e, st) {
      debugPrint('ONESIGNAL_DBG: OneSignal.logout() THREW: $e\n$st');
    }
  }

  /// Register a callback for when the user taps a push notification.
  /// [additionalData] is whatever payload the server attached to
  /// the push (we use this to route inside the app).
  void addClickListener(
    void Function(Map<String, dynamic> additionalData) callback,
  ) {
    debugPrint('ONESIGNAL_DBG: Notifications.addClickListener registered');
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      debugPrint(
        'ONESIGNAL_DBG: notification clicked — '
        'notificationId=${event.notification.notificationId}, '
        'additionalData=$data',
      );
      callback(data ?? const <String, dynamic>{});
    });
  }
}
