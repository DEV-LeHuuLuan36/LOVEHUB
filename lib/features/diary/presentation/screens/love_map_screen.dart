import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/theme/theme.dart';

class LoveMapScreen extends StatefulWidget {
  const LoveMapScreen({super.key});

  @override
  State<LoveMapScreen> createState() => _LoveMapScreenState();
}

class _LoveMapScreenState extends State<LoveMapScreen> {
  static const _initialPosition = LatLng(10.7769, 106.7009); // Ho Chi Minh City
  GoogleMapController? _mapController;
  String? _selectedMarkerId;

  static const _places = [
    _MapPlaceItem(
      id: 'p1',
      latLng: LatLng(10.7769, 106.7009),
      title: 'First Date 💕',
      subtitle: 'March 9, 2024',
      location: 'Quận 1',
    ),
    _MapPlaceItem(
      id: 'p2',
      latLng: LatLng(10.7544, 106.6934),
      title: 'Movie Night 🎬',
      subtitle: 'August 22, 2024',
      location: 'CGV Vincom',
    ),
    _MapPlaceItem(
      id: 'p3',
      latLng: LatLng(10.8231, 106.6297),
      title: 'Pho Date 🍜',
      subtitle: 'January 15, 2024',
      location: 'Pho Thin Lo Duc',
    ),
    _MapPlaceItem(
      id: 'p4',
      latLng: LatLng(10.7624, 106.6550),
      title: 'Coffee Shop ☕',
      subtitle: 'April 3, 2024',
      location: 'The Coffee House',
    ),
  ];

  Set<Marker> get _markers {
    return _places.map((place) {
      return Marker(
        markerId: MarkerId(place.id),
        position: place.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        onTap: () => setState(() => _selectedMarkerId = place.id),
      );
    }).toSet();
  }

  _MapPlaceItem? get _selectedPlace {
    if (_selectedMarkerId == null) return null;
    return _places.firstWhere((p) => p.id == _selectedMarkerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Stack(
        children: [
          // Full screen Google Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _initialPosition,
              zoom: 13,
            ),
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
            onTap: (_) => setState(() => _selectedMarkerId = null),
            style: _darkMapStyle,
          ),

          // Header overlay
          Positioned(
            top: 0, left: 0, right: 0,
            child: _GlassAppBar(
              title: '🗺️ ${'memory.loveMap.title'.tr()}',
              trailing: GestureDetector(
                onTap: () => _showSnackBar(context, 'memory.loveMap.addPlaceSoon'.tr()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 14, color: Colors.white),
                      const SizedBox(width: 3),
                      Text('memory.loveMap.addPlace'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // FAB
          Positioned(
            bottom: 360, right: 16,
            child: _FloatingPinkButton(
              icon: Icons.add,
              onTap: () => _showSnackBar(context, 'memory.loveMap.addPlaceSoon'.tr()),
            ),
          ),

          // Bottom sheet
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.2,
            maxChildSize: 0.75,
            builder: (context, scrollController) {
              return _LoveMapBottomSheet(
                scrollController: scrollController,
                places: _places,
                selectedPlace: _selectedPlace,
                onPlaceTap: (place) {
                  setState(() => _selectedMarkerId = place.id);
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(place.latLng, 15),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.gradientEnd,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
    );
  }

  // Dark map style matching the app's dark theme
  static const _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1d2c4d"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8ec3b9"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a3646"}]},
  {"featureType": "administrative.country", "elementType": "geometry.stroke", "stylers": [{"color": "#4b6878"}]},
  {"featureType": "administrative.land_parcel", "elementType": "labels.text.fill", "stylers": [{"color": "#64779e"}]},
  {"featureType": "administrative.province", "elementType": "geometry.stroke", "stylers": [{"color": "#4b6878"}]},
  {"featureType": "landscape.man_made", "elementType": "geometry.stroke", "stylers": [{"color": "#334e87"}]},
  {"featureType": "landscape.natural", "elementType": "geometry", "stylers": [{"color": "#023e58"}]},
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

class _MapPlaceItem {
  const _MapPlaceItem({
    required this.id, required this.latLng, required this.title,
    required this.subtitle, required this.location,
  });
  final String id;
  final LatLng latLng;
  final String title;
  final String subtitle;
  final String location;
}

// ─── GLASS APP BAR ───────────────────────────────────────────────────────────
class _GlassAppBar extends StatelessWidget {
  const _GlassAppBar({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
            border: const Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderSubtle, width: 1),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white))),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

// ─── BOTTOM SHEET ────────────────────────────────────────────────────────────
class _LoveMapBottomSheet extends StatelessWidget {
  const _LoveMapBottomSheet({
    required this.scrollController,
    required this.places,
    required this.selectedPlace,
    required this.onPlaceTap,
  });

  final ScrollController scrollController;
  final List<_MapPlaceItem> places;
  final _MapPlaceItem? selectedPlace;
  final ValueChanged<_MapPlaceItem> onPlaceTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.borderSubtle, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('memory.loveMap.memoriesCount'.tr(args: ['${places.length}']), style: AppTypography.titleMedium),
                    const Text('💕', style: TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Horizontal scroll cards
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: places.length,
                    itemBuilder: (context, i) {
                      final place = places[i];
                      final isSelected = selectedPlace?.id == place.id;
                      return Padding(
                        padding: EdgeInsets.only(right: i < places.length - 1 ? AppSpacing.xs : 0),
                        child: _MapMemoryCard(
                          place: place,
                          isSelected: isSelected,
                          onTap: () => onPlaceTap(place),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Full list
                ...places.map((place) => _PlaceListTile(place: place, onTap: () => onPlaceTap(place))),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapMemoryCard extends StatelessWidget {
  const _MapMemoryCard({required this.place, required this.isSelected, required this.onTap});
  final _MapPlaceItem place;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.borderSubtle,
            width: 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.35), blurRadius: 10)]
              : null,
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💕', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(place.title.split(' ').first, style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(place.subtitle, style: TextStyle(
              fontSize: 9, color: isSelected ? Colors.white70 : AppColors.textSecondary,
            ), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _PlaceListTile extends StatelessWidget {
  const _PlaceListTile({required this.place, required this.onTap});
  final _MapPlaceItem place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Center(child: Text('💕', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Text('📍', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 3),
                      Expanded(child: Text(place.location, style: AppTypography.labelSmall, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
            Text(place.subtitle, style: AppTypography.labelSmall),
          ],
        ),
      ),
    );
  }
}

// ─── FAB ─────────────────────────────────────────────────────────────────────
class _FloatingPinkButton extends StatelessWidget {
  const _FloatingPinkButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 1),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
