import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../data/services/location_service.dart';

/// Friendly empty-state shown when location is unavailable:
///  - Permission denied / denied forever  → CTA to open settings.
///  - Service disabled                     → CTA to open settings.
///  - Error                                → CTA to retry.
class PermissionDeniedView extends StatelessWidget {
  const PermissionDeniedView({
    super.key,
    required this.status,
    required this.onOpenSettings,
    required this.onRetry,
  });

  final LocationPermissionStatus status;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  ({String title, String body, IconData icon, String primaryLabel}) _content() {
    switch (status) {
      case LocationPermissionStatus.denied:
        return (
          title: 'coupleMap.permission.title'.tr(),
          body: 'coupleMap.permission.bodyDenied'.tr(),
          icon: Icons.location_off_rounded,
          primaryLabel: 'coupleMap.permission.openSettings'.tr(),
        );
      case LocationPermissionStatus.deniedForever:
        return (
          title: 'coupleMap.permission.title'.tr(),
          body: 'coupleMap.permission.bodyDeniedForever'.tr(),
          icon: Icons.location_disabled_rounded,
          primaryLabel: 'coupleMap.permission.openSettings'.tr(),
        );
      case LocationPermissionStatus.serviceDisabled:
        return (
          title: 'coupleMap.permission.title'.tr(),
          body: 'coupleMap.permission.bodyServiceDisabled'.tr(),
          icon: Icons.gps_off_rounded,
          primaryLabel: 'coupleMap.permission.openSettings'.tr(),
        );
      case LocationPermissionStatus.error:
        return (
          title: 'coupleMap.permission.title'.tr(),
          body: 'coupleMap.permission.bodyError'.tr(),
          icon: Icons.error_outline_rounded,
          primaryLabel: 'coupleMap.permission.retry'.tr(),
        );
      case LocationPermissionStatus.granted:
        return (
          title: '',
          body: '',
          icon: Icons.check_circle_rounded,
          primaryLabel: '',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _content();
    return Positioned.fill(
      child: Container(
        color: AppColors.backgroundPrimary,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.gradientEnd.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Icon(c.icon, size: 36, color: AppColors.gradientEnd),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              c.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              c.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GestureDetector(
              onTap: () {
                // For "denied" / "deniedForever" / "serviceDisabled"
                // open system settings. For "error" retry.
                if (status == LocationPermissionStatus.error) {
                  onRetry();
                } else {
                  onOpenSettings();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  boxShadow: AppColors.pinkGlow(intensity: 10),
                ),
                child: Text(
                  c.primaryLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}