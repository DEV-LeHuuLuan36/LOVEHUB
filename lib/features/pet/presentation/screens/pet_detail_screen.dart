import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';

class PetDetailScreen extends StatelessWidget {
  const PetDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              const _Header(),
              const SizedBox(height: AppSpacing.lg),
              const _PetHeroSection(),
              const SizedBox(height: AppSpacing.md),
              const _VitalsCard(),
              const SizedBox(height: AppSpacing.md),
              const _QuickActions(),
              const SizedBox(height: AppSpacing.md),
              const _LevelProgressCard(),
              const SizedBox(height: AppSpacing.md),
              const _PetHistoryTimeline(),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── HEADER ──────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

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
        Text('pet.detailMochi'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.gradientEnd, width: 1.5),
          ),
          child: Text('pet.statsLabel'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gradientEnd)),
        ),
      ],
    );
  }
}

// ─── PET HERO SECTION ────────────────────────────────────────────────────────
class _PetHeroSection extends StatelessWidget {
  const _PetHeroSection();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radial glow
          Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.gradientEnd.withValues(alpha: 0.25),
                  AppColors.gradientEnd.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),

          // Emotion bubble top
          Positioned(
            top: 0,
            right: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.borderSubtle, width: 1),
              ),
              child: Text('pet.moodHappy'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ).animate().fadeIn().slideY(begin: -0.3),
          ),

          // Level badge top right
          Positioned(
            top: 0,
            left: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
              ),
              child: Text('pet.levelShort'.tr(args: ['7']), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFFFD700))),
            ),
          ),

          // Pet chibi cat
          const Center(
            child: Text(
              '(^・ω・^)',
              style: TextStyle(fontSize: 100),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: -8, duration: const Duration(milliseconds: 1600), curve: Curves.easeInOut),

          // Outfit indicator bottom
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('pet.defaultOutfit'.tr(), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── VITALS CARD ─────────────────────────────────────────────────────────────
class _VitalsCard extends StatelessWidget {
  const _VitalsCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('pet.vitals'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.md),

          // HP bar
          Row(
            children: [
              const Text('❤️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('pet.hpBar'.tr(args: ['85', '100']), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    _StatBar(progress: 0.85, colors: [const Color(0xFF4CAF50), const Color(0xFF8BC34A)]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // EXP bar
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('pet.expBar'.tr(args: ['340', '700']), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    _StatBar(progress: 340 / 700, colors: [const Color(0xFF9C27B0), const Color(0xFFE040FB)]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Mood row
          Row(
            children: [
              const Text('😊', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text('pet.currentMoodHappy'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFFFD700))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Text('🍣', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text('pet.fedAgo'.tr(args: ['2']), style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.8))),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

// ─── QUICK ACTIONS ────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ActionButton(emoji: '🍣', label: 'pet.feed'.tr(), costLp: 20, reward: 'pet.rewardHp30'.tr(), rewardColor: const Color(0xFF4CAF50))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _ActionButton(emoji: '🎮', label: 'pet.play'.tr(), costLp: 15, reward: 'pet.rewardExp20'.tr(), rewardColor: const Color(0xFF9C27B0))),
        const SizedBox(width: AppSpacing.sm),
        _ActionButton(emoji: '💊', label: 'pet.heal'.tr(), costLp: 30, reward: 'pet.rewardHp50'.tr(), rewardColor: const Color(0xFF4CAF50), isHeal: true, showCondition: false),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.emoji, required this.label,
    required this.costLp, required this.reward, required this.rewardColor,
    this.isHeal = false, this.showCondition = true,
  });

  final String emoji;
  final String label;
  final int costLp;
  final String reward;
  final Color rewardColor;
  final bool isHeal;
  final bool showCondition;

  @override
  Widget build(BuildContext context) {
    // Heal button only shows when HP < 50 (always shows in this mock)
    if (!showCondition) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      child: Column(
        children: [
          // Cost chip top right
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('-$costLp LP', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.red)),
            ),
          ),
          Text(emoji, style: const TextStyle(fontSize: 32)),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: rewardColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(reward, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: rewardColor)),
          ),
        ],
      ),
    );
  }
}

// ─── LEVEL PROGRESS CARD ──────────────────────────────────────────────────────
class _LevelProgressCard extends StatelessWidget {
  const _LevelProgressCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('pet.levelProgress'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text('pet.levelFull'.tr(args: ['7']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFFFD700))),
              ),
              const Spacer(),
              Text('pet.levelFull'.tr(args: ['8']), style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          Text('340 / 700 XP', style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.7))),
          const SizedBox(height: 6),
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: BorderRadius.circular(7),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (340 / 700).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Perks
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('pet.perksUnlockedAt'.tr(args: ['8']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text('pet.unlockSummer'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('pet.unlockBeach'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PET HISTORY TIMELINE ─────────────────────────────────────────────────────
class _PetHistoryTimeline extends StatelessWidget {
  const _PetHistoryTimeline();

  static const _activities = [
    _ActivityItem(emoji: '🍣', textKey: 'pet.activity.fedMochi', subtext: 'pet.rewardHp30', timeKey: 'common.timeAgo.hoursAgoShort', timeArg: '2'),
    _ActivityItem(emoji: '💕', textKey: 'pet.activity.checkedIn', subtext: 'pet.rewardHp10', timeKey: 'common.timeAgo.hoursAgoShort', timeArg: '5'),
    _ActivityItem(emoji: '✨', textKey: 'pet.activity.levelUp', subtext: '', timeKey: 'common.timeAgo.daysAgoShort', timeArg: '2'),
    _ActivityItem(emoji: '😊', textKey: 'pet.activity.moodMatch', subtext: 'pet.rewardLp15', timeKey: 'common.timeAgo.daysAgoShort', timeArg: '3'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Text('pet.recentActivity'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ),
        GlassCard(
          child: Column(
            children: _activities.asMap().entries.map((entry) {
              final i = entry.key;
              final a = entry.value;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text(a.emoji, style: const TextStyle(fontSize: 16))),
                      ),
                      if (i < _activities.length - 1)
                        Container(width: 1, height: 30, color: AppColors.borderSubtle.withValues(alpha: 0.4)),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(a.textKey.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              if (a.subtext.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(a.subtext.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50))),
                              ],
                            ],
                          ),
                          Text(
                            a.timeArg == null ? a.timeKey.tr() : a.timeKey.tr(args: [a.timeArg!]),
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.emoji,
    required this.textKey,
    required this.subtext,
    required this.timeKey,
    this.timeArg,
  });
  final String emoji;
  final String textKey;
  final String subtext;
  final String timeKey;
  final String? timeArg;
}
