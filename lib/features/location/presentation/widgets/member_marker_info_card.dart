import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/entities/member_location.dart';

/// Bottom info card that appears when the user taps a marker.
/// Shows the member's name, the age of the position, and a
/// "last known" badge when the position is stale.
class MemberMarkerInfoCard extends StatelessWidget {
  const MemberMarkerInfoCard({
    super.key,
    required this.name,
    required this.location,
    required this.hue,
    required this.isMe,
  });

  final String name;
  final MemberLocation? location;
  final double hue;
  final bool isMe;

  String _ageLabel(DateTime? ts) {
    if (ts == null) return 'coupleMap.lastSeen.never'.tr();
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'coupleMap.lastSeen.justNow'.tr();
    if (diff.inMinutes < 60) {
      return 'coupleMap.lastSeen.minutesAgo'.tr(namedArgs: {
        'n': '${diff.inMinutes}',
      });
    }
    if (diff.inHours < 24) {
      return 'coupleMap.lastSeen.hoursAgo'.tr(namedArgs: {
        'n': '${diff.inHours}',
      });
    }
    return 'coupleMap.lastSeen.daysAgo'.tr(namedArgs: {
      'n': '${diff.inDays}',
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = location;
    final isStale = loc != null && !loc.isFresh;
    final hasNoPosition = loc == null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: HSLColor.fromAHSL(1, hue, 0.8, 0.55).toColor()
                  .withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: HSLColor.fromAHSL(1, hue, 0.8, 0.55).toColor(),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                isMe ? '🩷' : '💙',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          'coupleMap.you'.tr(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (hasNoPosition)
                  Text(
                    'coupleMap.noPositionYet'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                    ),
                  )
                else
                  Row(
                    children: [
                      Text(
                        _ageLabel(loc.updatedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.85),
                        ),
                      ),
                      if (isStale) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundPrimary,
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                              color: AppColors.gradientEnd
                                  .withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'coupleMap.lastKnownBadge'.tr(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gradientEnd,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}