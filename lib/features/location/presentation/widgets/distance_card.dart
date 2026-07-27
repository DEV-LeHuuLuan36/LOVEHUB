import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

/// Top-of-screen card that shows the distance between me and my
/// partner. Updates in real time as either position changes.
///
/// Format:
///  - ≥1 km  → "Cách nhau 3.2 km"
///  - <1 km  → "Cách nhau 320 m"
class DistanceCard extends StatelessWidget {
  const DistanceCard({super.key, required this.distanceMeters});

  final double? distanceMeters;

  String _format(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000.0;
      return 'coupleMap.distanceKm'.tr(namedArgs: {
        'km': km.toStringAsFixed(km >= 10 ? 0 : 1),
      });
    }
    return 'coupleMap.distanceMeters'.tr(namedArgs: {
      'm': '${meters.round()}',
    });
  }

  @override
  Widget build(BuildContext context) {
    final meters = distanceMeters;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: AppColors.pinkGlow(intensity: 14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💞', style: TextStyle(fontSize: 16)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            meters == null
                ? 'coupleMap.distanceLoading'.tr()
                : _format(meters),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}