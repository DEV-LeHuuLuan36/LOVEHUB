import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';

class MilestoneScreen extends StatefulWidget {
  const MilestoneScreen({super.key});

  @override
  State<MilestoneScreen> createState() => _MilestoneScreenState();
}

class _MilestoneScreenState extends State<MilestoneScreen> {
  Timer? _timer;
  int _seconds = 0;

  static const _upcomingMilestones = [
    _MilestoneData(name: '1 Year Anniversary', emoji: '💑', date: 'March 9, 2025', daysLeft: 45),
    _MilestoneData(name: "Linh's Birthday", emoji: '🎂', date: 'July 15, 2025', daysLeft: 36),
    _MilestoneData(name: "Valentine's Day", emoji: '💝', date: 'Feb 14, 2026', daysLeft: 250),
    _MilestoneData(name: '500 Days Together', emoji: '🌟', date: 'July 22, 2025', daysLeft: 43),
  ];

  static const _pastMilestones = [
    _MilestoneData(name: '100 Days Together', emoji: '🎯', date: 'June 17, 2024'),
    _MilestoneData(name: 'First Month Streak', emoji: '🔥', date: 'April 9, 2024'),
    _MilestoneData(name: 'First Date Anniversary', emoji: '💕', date: 'March 9, 2024'),
  ];

  static const _categories = ['All', 'Anniversary 💑', 'Birthday 🎂', 'Streak 🔥', 'Custom ⭐'];
  int _activeCategory = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    _Header(onAddTap: () => context.push(AppRoutes.addMilestone)),
                    const SizedBox(height: AppSpacing.lg),
                    _NextMilestoneCard(seconds: _seconds),
                    const SizedBox(height: AppSpacing.lg),
                    _CategoryChips(
                      categories: _categories,
                      active: _activeCategory,
                      onSelect: (i) => setState(() => _activeCategory = i),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _UpcomingMilestonesList(milestones: _upcomingMilestones),
                    const SizedBox(height: AppSpacing.lg),
                    _PastMilestonesSection(milestones: _pastMilestones),
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
}

// ─── HEADER ──────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.onAddTap});
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        const Spacer(),
        Text('🎯 ${'milestone.title'.tr()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const Spacer(),
        GestureDetector(
          onTap: onAddTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.full),
              boxShadow: [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.35), blurRadius: 8)],
            ),
            child: Text('+ ${'common.add'.tr()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

// ─── NEXT MILESTONE HERO CARD ────────────────────────────────────────────────
class _NextMilestoneCard extends StatelessWidget {
  const _NextMilestoneCard({required this.seconds});

  final int seconds;

  static const _targetDate = 'March 9, 2025';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.2), blurRadius: 16, spreadRadius: 2),
        ],
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
              ),
              child: Text('milestone.comingUpNext'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFFD700))),
            ),
            const SizedBox(height: AppSpacing.md),

            // Milestone name
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
              ).createShader(bounds),
              child: const Text(
                '💑 1 Year Anniversary',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Countdown
            _LiveCountdown(seconds: seconds, daysLeft: 45),
            const SizedBox(height: AppSpacing.sm),

            // Date
            Text(_targetDate, style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.7))),
            const SizedBox(height: AppSpacing.sm),

            // Reminder chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('milestone.reminderSet'.tr(), style: const TextStyle(fontSize: 12, color: Color(0xFF00897B), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveCountdown extends StatelessWidget {
  const _LiveCountdown({required this.seconds, required this.daysLeft});

  final int seconds;
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    // seconds since midnight (0-86399), so we can compute hours/mins
    final secsOfDay = seconds % 86400;
    final hours = (secsOfDay ~/ 3600);
    final mins = ((secsOfDay % 3600) ~/ 60);
    final secs = secsOfDay % 60;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CountdownUnit(value: daysLeft, label: 'days'),
        const _CountdownColon(),
        _CountdownUnit(value: hours, label: 'hrs'),
        const _CountdownColon(),
        _CountdownUnit(value: mins, label: 'mins'),
        const _CountdownColon(),
        _CountdownUnit(value: secs, label: 'secs'),
      ],
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  const _CountdownUnit({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
          ).createShader(bounds),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.7))),
      ],
    );
  }
}

class _CountdownColon extends StatelessWidget {
  const _CountdownColon();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textSecondary.withValues(alpha: 0.5))),
    );
  }
}

// ─── CATEGORY CHIPS ──────────────────────────────────────────────────────────
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.categories, required this.active, required this.onSelect});

  final List<String> categories;
  final int active;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isActive = i == active;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isActive ? AppColors.primaryGradient : null,
                color: isActive ? null : AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: isActive ? null : Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                categories[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── UPCOMING MILESTONES LIST ─────────────────────────────────────────────────
class _MilestoneData {
  const _MilestoneData({required this.name, required this.emoji, required this.date, this.daysLeft});
  final String name;
  final String emoji;
  final String date;
  final int? daysLeft;
}

class _UpcomingMilestonesList extends StatelessWidget {
  const _UpcomingMilestonesList({required this.milestones});

  final List<_MilestoneData> milestones;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Text('milestone.upcoming'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ),
        ...milestones.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _MilestoneListTile(data: m, isPast: false),
        )),
      ],
    );
  }
}

// ─── PAST MILESTONES ─────────────────────────────────────────────────────────
class _PastMilestonesSection extends StatelessWidget {
  const _PastMilestonesSection({required this.milestones});

  final List<_MilestoneData> milestones;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Text('milestone.achieved'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ),
        ...milestones.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _MilestoneListTile(data: m, isPast: true),
        )),
      ],
    );
  }
}

class _MilestoneListTile extends StatelessWidget {
  const _MilestoneListTile({required this.data, required this.isPast});

  final _MilestoneData data;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          // Left icon
          if (!isPast)
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient.scale(0.4),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(data.emoji, style: const TextStyle(fontSize: 20))),
            )
          else
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('✅', style: TextStyle(fontSize: 18))),
            ),
          const SizedBox(width: AppSpacing.sm),

          // Center
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isPast ? AppColors.textSecondary : AppColors.textPrimary)),
                Text(data.date, style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.7))),
              ],
            ),
          ),

          // Right badge
          if (!isPast && data.daysLeft != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.full),
            ),
              child: Text(
                'in ${data.daysLeft} days',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFFD700)),
              ),
            )
          else if (isPast)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('milestone.celebrated'.tr(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50))),
            )
          else
            Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }
}
