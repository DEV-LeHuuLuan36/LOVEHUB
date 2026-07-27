import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Distilled shape of a geolocator update, decoupled from the
/// `Position` type so the rest of the app doesn't need to depend
/// on the package directly.
class AppLatLng {
  const AppLatLng(this.lat, this.lng, {required this.accuracyMeters});
  final double lat;
  final double lng;
  final double accuracyMeters;
}

/// Foreground location service. Wraps `geolocator` so the rest of
/// the app deals with a tiny pure-Dart API.
///
/// Behavior:
///  - Permission flow is explicit and returns a typed enum (so the
///    UI can decide between asking, showing settings, or hiding).
///  - `startStream()` returns a throttled `Stream<AppLatLng>`:
///      * `distanceFilter: 50m` — geolocator itself drops samples
///        that moved less than 50m from the last accepted one.
///      * Additional time gate of 30s — even if the device emits
///        a noisy position while the user is stationary, we don't
///        surface more than one update every 30 seconds.
///  - Foreground-only: the screen only ever reads location while
///    open. We never ask for `LocationPermission.always` and the
///    manifest does not include `ACCESS_BACKGROUND_LOCATION`.
class LocationService {
  static const int _distanceFilterMeters = 50;
  static const Duration _minInterval = Duration(seconds: 30);

  /// Foreground-only settings — accuracy high, 50m gate, 60s cap.
  /// The base `LocationSettings` class works on both Android and iOS,
  /// which keeps the package list minimal (we only depend on
  /// `geolocator`, not on `geolocator_android`/`geolocator_apple`).
  /// `timeLimit` prevents the stream from stalling indefinitely if
  /// the GPS hardware becomes unresponsive.
  static final LocationSettings _settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: _distanceFilterMeters,
    timeLimit: const Duration(seconds: 60),
  );

  /// Asks for permission if needed. Never throws — returns a typed
  /// enum that the UI converts to a friendly state.
  Future<LocationPermissionStatus> ensurePermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return LocationPermissionStatus.serviceDisabled;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
        case LocationPermission.unableToDetermine:
          return LocationPermissionStatus.granted;
        case LocationPermission.denied:
          return LocationPermissionStatus.denied;
        case LocationPermission.deniedForever:
          return LocationPermissionStatus.deniedForever;
      }
    } catch (e) {
      debugPrint('LOCATION_DBG_ERR: ensurePermission: $e');
      return LocationPermissionStatus.error;
    }
  }

  /// Opens the OS settings page so the user can grant the
  /// permission after tapping "Open settings".
  Future<void> openSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('LOCATION_DBG_ERR: openSettings: $e');
    }
  }

  /// One-shot read so the marker can appear instantly on screen
  /// before the stream starts emitting. Returns `null` if reading
  /// fails (e.g. permission was just revoked, or the GPS times out
  /// after 15 s).
  Future<AppLatLng?> getCurrentPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('getCurrentPosition timed out'),
      );
      return AppLatLng(pos.latitude, pos.longitude,
          accuracyMeters: pos.accuracy);
    } catch (e) {
      debugPrint('LOCATION_DBG_ERR: getCurrentPosition: $e');
      return null;
    }
  }

  /// Throttled foreground position stream. The caller is
  /// responsible for cancelling the subscription (done in
  /// `CoupleMapScreen.dispose`).
  Stream<AppLatLng> startStream() {
    final controller = StreamController<AppLatLng>.broadcast();

    StreamSubscription<Position>? sub;
    DateTime? lastEmittedAt;
    AppLatLng? lastEmitted;

    controller.onListen = () async {
      try {
        sub = Geolocator.getPositionStream(locationSettings: _settings).listen(
          (pos) {
            final candidate = AppLatLng(
              pos.latitude,
              pos.longitude,
              accuracyMeters: pos.accuracy,
            );

            // Defensive 50m gate. `geolocator` already applies
            // `distanceFilter`, but the OS occasionally emits
            // small drifts even when the device is stationary.
            if (lastEmitted != null) {
              final moved = Geolocator.distanceBetween(
                lastEmitted!.lat,
                lastEmitted!.lng,
                candidate.lat,
                candidate.lng,
              );
              if (moved < _distanceFilterMeters) return;
            }

            // Soft 30s gate.
            final now = DateTime.now();
            if (lastEmittedAt != null &&
                now.difference(lastEmittedAt!) < _minInterval) {
              return;
            }

            lastEmitted = candidate;
            lastEmittedAt = now;
            if (!controller.isClosed) controller.add(candidate);
          },
          onError: (Object e, StackTrace st) {
            debugPrint('LOCATION_DBG_ERR: positionStream: $e');
            // Don't emit on stream errors — the screen handles
            // the absence of new positions gracefully.
          },
          cancelOnError: false,
        );
      } catch (e) {
        debugPrint('LOCATION_DBG_ERR: startStream: $e');
      }
    };

    controller.onCancel = () async {
      await sub?.cancel();
      sub = null;
    };

    return controller.stream;
  }
}

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  error,
}