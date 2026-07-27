import 'dart:async';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../../presence/presentation/providers/presence_providers.dart';
import '../../data/services/location_service.dart';
import '../../domain/entities/member_location.dart';
import '../../domain/usecases/update_my_location_usecase.dart';
import '../providers/location_providers.dart';
import '../widgets/distance_card.dart';
import '../widgets/member_marker_info_card.dart';
import '../widgets/permission_denied_view.dart';

/// Real-time map showing the current user and their partner.
///
/// Read path: subscribes to `myLocationProvider` and
/// `partnerLocationProvider` (Firestore snapshots) and rebuilds
/// the markers live as either position changes.
///
/// Write path: requests location permission on `initState`, then
/// starts the throttled `Geolocator` stream (50m + 30s gate) and
/// writes each accepted position to
/// `locations/{coupleId}/members/{myUid}`.
///
/// Lifecycle: the geolocator subscription and the
/// "re-fit on update" debounce are both cancelled in `dispose()`.
class CoupleMapScreen extends ConsumerStatefulWidget {
  const CoupleMapScreen({super.key});

  @override
  ConsumerState<CoupleMapScreen> createState() => _CoupleMapScreenState();
}

class _CoupleMapScreenState extends ConsumerState<CoupleMapScreen> {
  // Ho Chi Minh City — a friendly default until we have a real
  // position to centre on. Matches the value used by the static
  // LoveMapScreen.
  static const _initialPosition = LatLng(10.7769, 106.7009);

  // Marker hue colors. Using `defaultMarkerWithHue` (the cheapest
  // path the Google Maps plugin gives us — no bitmap baking
  // needed) with a pink/rose hue for "me" and an azure hue for
  // "partner". The "stale" variant uses a lower-saturation hue
  // (hueRose + 30° ish) to render the marker slightly faded.
  static const double _meHue = BitmapDescriptor.hueRose;
  static const double _partnerHue = BitmapDescriptor.hueAzure;
  static const double _meHueStale = BitmapDescriptor.hueOrange;
  static const double _partnerHueStale = BitmapDescriptor.hueViolet;

  GoogleMapController? _mapController;
  StreamSubscription<AppLatLng>? _positionSub;
  Timer? _initialFitTimer;

  // For "re-fit on update" — only re-fit the camera when at
  // least one of the two positions moved materially, so a fresh
  // position reading doesn't yank the camera on every second.
  LatLng? _lastFittedMe;
  LatLng? _lastFittedPartner;

  // Which marker the user has tapped (drives the bottom info
  // card). Null = no card shown.
  String? _selectedMarkerId;

  // Permission state machine: null = still checking; otherwise
  // any of the LocationPermissionStatus values.
  LocationPermissionStatus? _permission;

  // BUG FIX: "Đang tính..." hangs forever when GPS never resolves.
  // _isLoading is true from _bootstrap start until either:
  //   - a seed position is successfully written to Firestore, OR
  //   - the timeout fires and _positionError is set.
  // This lets the UI show a spinner overlay rather than the silent
  // _InfoPill that never dismissed (myLoc came from a Firestore stream
  // that hadn't emitted yet, so myLoc stayed null and the pill stayed).
  bool _isLoading = true;
  String? _positionError; // non-null = show retry card instead of spinner

  @override
  void initState() {
    super.initState();
    // Defer to the next frame so the Riverpod container is
    // already built and we can read providers safely.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final service = ref.read(locationServiceProvider);
    final status = await service.ensurePermission();
    if (!mounted) return;
    setState(() => _permission = status);

    if (status == LocationPermissionStatus.granted) {
      // Seed the marker immediately with a one-shot read so the
      // user doesn't stare at a blank map while the stream
      // warms up. Dismiss the spinner as soon as we get a fix —
      // don't wait for the Firestore stream to propagate (that
      // could take 1-2 s and made the "Đang tính..." pill look
      // broken).
      final seed = await service.getCurrentPosition();
      debugPrint(
        'COUPLE_MAP_DBG: getCurrentPosition returned ${seed != null ? 'FIX' : 'NULL'}',
      );
      if (!mounted) return;
      if (seed != null) {
        await _writePosition(seed);
        debugPrint('COUPLE_MAP_DBG: seed written to Firestore — dismissing spinner');
        setState(() => _isLoading = false);
      } else {
        // seed == null means either GPS timed out or an error occurred.
        // Show the retry card instead of an infinite spinner.
        debugPrint('COUPLE_MAP_DBG: seed is null — showing error, keeping spinner hidden');
        setState(() {
          _isLoading = false;
          _positionError = 'Không lấy được vị trí. Thử lại?';
        });
        // Don't start the stream if we have no seed — the retry
        // button will call _bootstrap again.
        return;
      }

      if (!mounted) return;
      _positionSub = service.startStream().listen(
        (pos) {
          debugPrint('COUPLE_MAP_DBG: stream event — ${pos.lat}, ${pos.lng}');
          _writePosition(pos);
        },
        onError: (Object e, StackTrace st) {
          debugPrint('LOCATION_DBG_ERR: positionSub stream error: $e');
        },
      );
    } else {
      // Permission denied — no point loading.
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _writePosition(AppLatLng pos) async {
    final coupleId = ref.read(currentCoupleIdProvider);
    final myUid = ref.read(authStateProvider).valueOrNull?.uid;
    if (coupleId == null || myUid == null) return;
    final UpdateMyLocationUseCase usecase =
        ref.read(updateMyLocationUseCaseProvider);
    final result = await usecase.call(
      coupleId: coupleId,
      uid: myUid,
      lat: pos.lat,
      lng: pos.lng,
    );
    result.fold(
      (failure) => debugPrint(
        'LOCATION_DBG_ERR: updateMyLocation: ${failure.message}',
      ),
      (_) {},
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _initialFitTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ─── Camera fitting ────────────────────────────────────────────────────────
  /// Fit camera so both markers are visible. Idempotent — only
  /// actually moves the camera if at least one position moved by
  /// a non-trivial amount since the last fit.
  void _maybeFitToBounds(LatLng? me, LatLng? partner) {
    if (me == null && partner == null) return;
    final controller = _mapController;
    if (controller == null) return;

    final moved = _hasMovedSignificantly(me, partner);
    if (!moved) return;

    if (me != null && partner != null) {
      // `newLatLngBounds` throws when southwest == northeast
      // (both members at the exact same spot). In that case,
      // fall back to a single-marker zoom.
      if (me.latitude == partner.latitude &&
          me.longitude == partner.longitude) {
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(me, 14),
        );
      } else {
        controller.animateCamera(
          CameraUpdate.newLatLngBounds(_boundsFor(me, partner), 96),
        );
      }
    } else {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(me ?? partner ?? _initialPosition, 14),
      );
    }
    _lastFittedMe = me;
    _lastFittedPartner = partner;
  }

  bool _hasMovedSignificantly(LatLng? me, LatLng? partner) {
    bool changed(LatLng? prev, LatLng? next) {
      if (prev == null && next == null) return false;
      if (prev == null || next == null) return true;
      // ~30m. More than that and we re-fit; less and we leave
      // the camera alone.
      final d = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        next.latitude,
        next.longitude,
      );
      return d > 30;
    }

    return changed(_lastFittedMe, me) ||
        changed(_lastFittedPartner, partner);
  }

  LatLngBounds _boundsFor(LatLng a, LatLng b) {
    final south = LatLng(
      a.latitude < b.latitude ? a.latitude : b.latitude,
      a.longitude < b.longitude ? a.longitude : b.longitude,
    );
    final north = LatLng(
      a.latitude > b.latitude ? a.latitude : b.latitude,
      a.longitude > b.longitude ? a.longitude : b.longitude,
    );
    return LatLngBounds(southwest: south, northeast: north);
  }

  // ─── Markers ──────────────────────────────────────────────────────────────
  Set<Marker> _buildMarkers(
    MemberLocation? me,
    MemberLocation? partner,
  ) {
    final markers = <Marker>{};

    if (me != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('me'),
          position: LatLng(me.lat, me.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            me.isFresh ? _meHue : _meHueStale,
          ),
          onTap: () => setState(() => _selectedMarkerId = 'me'),
        ),
      );
    }
    if (partner != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('partner'),
          position: LatLng(partner.lat, partner.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            partner.isFresh ? _partnerHue : _partnerHueStale,
          ),
          onTap: () => setState(() => _selectedMarkerId = 'partner'),
        ),
      );
    }
    return markers;
  }

  // ─── Names ────────────────────────────────────────────────────────────────
  ({String me, String partner}) _resolveNames(AppUser? authUser) {
    final meName = authUser?.displayName?.trim();
    final meFallback = (meName?.isNotEmpty ?? false)
        ? meName!
        : 'coupleMap.fallbackYou'.tr();
    return (me: meFallback, partner: 'coupleMap.fallbackPartner'.tr());
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final coupleId = ref.watch(currentCoupleIdProvider);
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final partnerId = ref.watch(partnerIdProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final partnerProfile = ref.watch(partnerProfileProvider).valueOrNull;

    final myAsync = ref.watch(myLocationProvider);
    final partnerAsync = ref.watch(partnerLocationProvider);

    final myLoc = myAsync.valueOrNull;
    final partnerLoc = partnerAsync.valueOrNull;

    final names = _resolveNames(authUser);
    final partnerName = partnerProfile?.displayName?.trim();
    final partnerDisplay = (partnerName?.isNotEmpty ?? false)
        ? partnerName!
        : names.partner;

    // If we don't yet have a couple or uids, render a friendly
    // empty state without the map (otherwise GoogleMap would
    // throw at runtime).
    if (coupleId == null || myUid == null || partnerId == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: _buildAppBar(),
        body: Center(
          child: Text(
            'coupleMap.noCouple'.tr(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    // Try to fit the camera to both markers whenever either
    // position updates.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeFitToBounds(
        myLoc != null ? LatLng(myLoc.lat, myLoc.lng) : null,
        partnerLoc != null ? LatLng(partnerLoc.lat, partnerLoc.lng) : null,
      );
    });

    final markers = _buildMarkers(myLoc, partnerLoc);

    final distance = _distanceMeters(myLoc, partnerLoc);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Stack(
        children: [
          // The map fills the whole screen. The dark style
          // matches the static LoveMapScreen for visual
          // consistency across the app.
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _initialPosition,
              zoom: 12,
            ),
            markers: markers,
            myLocationEnabled: false, // we render our own marker
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (c) {
              _mapController = c;
              _initialFitTimer?.cancel();
              // Re-fit once the controller is ready (in case
              // markers were already built by the time it was
              // attached).
              _initialFitTimer = Timer(
                const Duration(milliseconds: 300),
                () {
                  if (!mounted) return;
                  _maybeFitToBounds(
                    myLoc != null ? LatLng(myLoc.lat, myLoc.lng) : null,
                    partnerLoc != null
                        ? LatLng(partnerLoc.lat, partnerLoc.lng)
                        : null,
                  );
                },
              );
            },
            onTap: (_) => setState(() => _selectedMarkerId = null),
            style: _darkMapStyle,
          ),

          // Top app bar overlay (matches LoveMapScreen style).
          _buildAppBarOverlay(),

          // BUG FIX: a spinner overlay that blocks interaction while
          // GPS is resolving. Dismisses immediately when _bootstrap sets
          // _isLoading = false. Replaced by _positionError card if GPS
          // times out.
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: AppColors.backgroundPrimary.withValues(alpha: 0.75),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: AppColors.gradientEnd,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'coupleMap.loading'.tr(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'coupleMap.loadingSub'.tr(),
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // BUG FIX: retry card shown when GPS timed out or errored.
          // The map tiles still render underneath (no crash) so the user
          // can dismiss this and browse the map while retrying.
          if (_positionError != null)
            Positioned.fill(
              child: Container(
                color: AppColors.backgroundPrimary.withValues(alpha: 0.85),
                child: Center(
                  child: GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📡', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'coupleMap.positionError'.tr(),
                          style: AppTypography.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _positionError!,
                          style: AppTypography.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isLoading = true;
                              _positionError = null;
                            });
                            _bootstrap();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.button),
                            ),
                            child: Text(
                              'coupleMap.retry'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Distance pill at the top.
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 0,
            right: 0,
            child: Center(
              child: DistanceCard(distanceMeters: distance),
            ),
          ),

          // Empty-state note when nobody has any position yet.
          if (myLoc == null && partnerLoc == null)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: _InfoPill(
                  text: 'coupleMap.waitingForFirstFix'.tr(),
                  emoji: '🛰️',
                ),
              ),
            ),

          // Bottom info card for the selected marker.
          if (_selectedMarkerId != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.lg,
              child: MemberMarkerInfoCard(
                name: _selectedMarkerId == 'me'
                    ? names.me
                    : partnerDisplay,
                location: _selectedMarkerId == 'me' ? myLoc : partnerLoc,
                hue: _selectedMarkerId == 'me' ? _meHue : _partnerHue,
                isMe: _selectedMarkerId == 'me',
              ),
            ),

          // Permission-denied / service-disabled overlay.
          if (_permission != null &&
              _permission != LocationPermissionStatus.granted)
            PermissionDeniedView(
              status: _permission!,
              onOpenSettings: () =>
                  ref.read(locationServiceProvider).openSettings(),
              onRetry: () async {
                setState(() => _permission = null);
                await _bootstrap();
              },
            ),
        ],
      ),
    );
  }

  // ─── App bar ──────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.backgroundPrimary,
      elevation: 0,
      title: Text('🗺️ ${'home.map'.tr()}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildAppBarOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1025).withValues(alpha: 0.7),
              border: const Border(
                bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.borderSubtle, width: 1),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '🗺️ ${'home.map'.tr()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  double? _distanceMeters(MemberLocation? a, MemberLocation? b) {
    if (a == null || b == null) return null;
    return Geolocator.distanceBetween(a.lat, a.lng, b.lat, b.lng);
  }

  // Dark map style matching the rest of the app (the same JSON
  // used by the static LoveMapScreen, kept verbatim so both map
  // screens look identical).
  static const _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1d2c4d"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8ec3b9"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a3646"}]},
  {"featureType": "administrative.country", "elementType": "geometry.stroke", "stylers": [{"color": "#4b6878"}]},
  {"featureType": "administrative.land_parcel", "elementType": "labels.text.fill", "stylers": [{"color": "#64779e"}]},
  {"featureType": "administrative.province", "elementType": "geometry.stroke", "stylers": [{"color": "#4b6878"}]},
  {"featureType": "landscape.man_made", "elementType": "geometry.stroke", "stylers": [{"color": "#334e87"}]},
  {"featureType": "landscape.natural", "elementType": "geometry.stroke", "stylers": [{"color": "#334e87"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#283d6a"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#6f9ba5"}]},
  {"featureType": "poi", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
  {"featureType": "poi.park", "elementType": "geometry.fill", "stylers": [{"color": "#023e58"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#3C7680"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#304a7d"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#98a5be"}]},
  {"featureType": "road", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#2c6675"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#255763"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#b0d5ce"}]},
  {"featureType": "road.highway", "elementType": "labels.text.stroke", "stylers": [{"color": "#023e58"}]},
  {"featureType": "transit", "elementType": "labels.text.fill", "stylers": [{"color": "#98a5be"}]},
  {"featureType": "transit", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
  {"featureType": "transit.line", "elementType": "geometry.fill", "stylers": [{"color": "#283d6a"}]},
  {"featureType": "transit.station", "elementType": "geometry", "stylers": [{"color": "#3a4762"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0e1626"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#4e6d70"}]}
]
''';
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text, required this.emoji});
  final String text;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}