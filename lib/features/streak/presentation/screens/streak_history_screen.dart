import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../domain/entities/streak_entity.dart';
import '../providers/streak_providers.dart';

/// Full-history view shown when the user taps "View full history"
/// on the streak screen. Renders a month grid (current + adjacent
/// months) of check-in status per day, driven by the real
/// [checkins] map on the [StreakEntity].
class StreakHistoryScreen extends ConsumerStatefulWidget {
  const StreakHistoryScreen({super.key});

  @override
  ConsumerState<StreakHistoryScreen> createState() =>
      _StreakHistoryScreenState();
}

class _StreakHistoryScreenState extends ConsumerState<StreakHistoryScreen> {
  /// 0 = current month, -1 = previous, +1 = next.
  int _monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    final coupleId = ref.watch(currentCoupleIdProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;

    if (coupleId == null || authUser == null || partner == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: Center(
            child: Text(
              'streak.history.empty'.tr(),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    final streakAsync = ref.watch(watchStreakProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    _buildHeader(),
                    const SizedBox(height: AppSpacing.lg),
                    streakAsync.when(
                      data: (entity) => _buildMonthlyHeatmap(
                        entity: entity,
                        myUid: authUser.uid,
                        partnerId: partner.uid,
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Could not load history: $e',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildHeatmapLegend(),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Spacer(),
        const Text(
          '🔥 Streak History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildMonthlyHeatmap({
    required StreakEntity? entity,
    required String myUid,
    required String partnerId,
  }) {
    final now = DateTime.now();
    // The first day of the month we're displaying.
    final monthAnchor = DateTime(now.year, now.month + _monthOffset, 1);
    final daysInMonth = DateUtils.getDaysInMonth(monthAnchor.year, monthAnchor.month);
    // DateTime.weekday: Mon=1..Sun=7. We render Mon-first → offset = weekday-1.
    final firstWeekday = monthAnchor.weekday;
    final cellCount = ((firstWeekday - 1) + daysInMonth + 6) ~/ 7 * 7;
    final isCurrentMonth = _monthOffset == 0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _monthOffset--),
                child: Icon(
                  Icons.chevron_left,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                _monthLabel(monthAnchor),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _monthOffset > -12 && !isCurrentMonth
                    ? () => setState(() => _monthOffset++)
                    : null,
                child: Icon(
                  Icons.chevron_right,
                  color: isCurrentMonth
                      ? AppColors.textSecondary.withValues(alpha: 0.3)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (l) => SizedBox(
                    width: 36,
                    child: Text(
                      l,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: cellCount,
            itemBuilder: (context, i) {
              final dayNum = i - (firstWeekday - 1) + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(monthAnchor.year, monthAnchor.month, dayNum);
              final isFuture = date.isAfter(now);
              final isToday = isCurrentMonth && dayNum == now.day;
              final dateStr = _dateStr(date);
              final uids = entity?.checkins[dateStr] ?? const <String>{};
              final meOn = uids.contains(myUid);
              final partnerOn = uids.contains(partnerId);
              return _MonthDayCell(
                day: dayNum,
                isToday: isToday,
                isFuture: isFuture,
                meOn: meOn,
                partnerOn: partnerOn,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem('✅ Both', const Color(0xFF2E7D32)),
        const SizedBox(width: 12),
        _legendItem('⚡ One', const Color(0xFFFFD700)),
        const SizedBox(width: 12),
        _legendItem('❌ Missed', const Color(0xFF2A2A2A)),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  static String _dateStr(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _monthLabel(DateTime d) {
    return '${_monthNames[d.month - 1]} ${d.year}';
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.day,
    required this.isToday,
    required this.isFuture,
    required this.meOn,
    required this.partnerOn,
  });

  final int day;
  final bool isToday;
  final bool isFuture;
  final bool meOn;
  final bool partnerOn;

  @override
  Widget build(BuildContext context) {
    final bothOn = meOn && partnerOn;
    final anyOn = meOn || partnerOn;

    Color fill;
    Color textColor;
    if (isFuture) {
      fill = AppColors.backgroundCard.withValues(alpha: 0.3);
      textColor = AppColors.textSecondary.withValues(alpha: 0.3);
    } else if (bothOn) {
      fill = const Color(0xFF2E7D32);
      textColor = Colors.white;
    } else if (anyOn) {
      fill = const Color(0xFFFFD700);
      textColor = const Color(0xFF1A1025);
    } else {
      fill = const Color(0xFF2A2A2A);
      textColor = Colors.white.withValues(alpha: 0.5);
    }

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
        border: isToday
            ? Border.all(color: AppColors.gradientEnd, width: 2)
            : null,
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
