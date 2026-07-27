import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../../diary/presentation/providers/memory_providers.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../../gamification/domain/entities/pet_entity.dart';
import '../../../gamification/domain/entities/pet_mission_entity.dart';
import '../../../gamification/presentation/providers/pet_providers.dart';
import '../../../mood/presentation/providers/mood_providers.dart';
import '../../../streak/presentation/providers/streak_providers.dart';

/// Pet missions screen.
///
/// Mission completion is now driven by live data instead of static
/// `const` flags:
///
///   • bothCheckIn → `StreakEntity.bothCheckedToday`
///   • shareMood   → `watchTodayMoodProvider` is non-null (you shared today)
///   • addDiary    → `watchMemoriesProvider` was updated today
///   • feedPet     → `PetMissionEntity.fedToday`
///   • patPet      → pat count today ≥ [PetEntity.maxPatPerDay]
///
/// Weekly missions stay as the curated list they were — those are
/// long-horizon, derived stats that aren't worth computing live.
class PetMissionsScreen extends ConsumerStatefulWidget {
  const PetMissionsScreen({super.key});

  @override
  ConsumerState<PetMissionsScreen> createState() => _PetMissionsScreenState();
}

class _PetMissionsScreenState extends ConsumerState<PetMissionsScreen> {
  bool _rewardClaimed = false;
  bool _showConfetti = false;

  // ─── DAILY ─────────────────────────────────────────────────────────────────
  List<_MissionItem> _dailyMissionsList(PetMissionEntity? missionEntity) {
    final bothCheckIn = ref.watch(watchStreakProvider).valueOrNull?.bothCheckedToday ?? false;
    final moodAsync = ref.watch(watchTodayMoodProvider);
    final shareMood = moodAsync.valueOrNull != null;
    final memoriesAsync = ref.watch(watchMemoriesProvider);
    final memories = memoriesAsync.valueOrNull ?? const [];
    final today = _todayKey();
    final addDiary = memories.any((m) => _dateKeyOf(m.date) == today);

    return [
      _MissionItem(
        emoji: '💕',
        titleKey: 'missions.daily.bothCheckIn',
        reward: '+10 LP',
        isDone: bothCheckIn,
      ),
      _MissionItem(
        emoji: '😊',
        titleKey: 'missions.daily.shareMood',
        reward: '+5 LP',
        isDone: shareMood,
      ),
      _MissionItem(
        emoji: '📖',
        titleKey: 'missions.daily.addDiary',
        reward: '+20 LP',
        isDone: addDiary,
        isNavigation: !addDiary,
      ),
      _MissionItem(
        emoji: '🍖',
        titleKey: 'missions.daily.feedPet',
        reward: '+5 LP',
        isDone: missionEntity?.fedToday ?? false,
        isNavigation: !(missionEntity?.fedToday ?? false),
      ),
      _MissionItem(
        emoji: '🐱',
        titleKey: 'missions.daily.patPet',
        reward: '+5 LP',
        isDone: missionEntity?.patPetDoneToday(PetEntity.maxPatPerDay) ?? false,
        isNavigation: !(missionEntity?.patPetDoneToday(PetEntity.maxPatPerDay) ?? false),
      ),
    ];
  }

  // ─── WEEKLY (derived from live data) ────────────────────────────────────────
  static const _weeklyMaxStreak = 7;
  static const _weeklyMaxDiary = 3;
  static const _weeklyMaxMood = 5;

  List<_MissionItem> _weeklyMissionsList(
    int currentStreak,
    int diaryCountThisWeek,
    int moodDaysThisWeek,
    bool hasSavingJar,
  ) {
    return [
      _MissionItem(
        emoji: '🔥',
        titleKey: 'missions.weekly.maintainStreak',
        reward: '+50 LP',
        isDone: currentStreak >= _weeklyMaxStreak,
        progress: '$currentStreak/$_weeklyMaxStreak',
        progressMax: _weeklyMaxStreak,
        progressCurrent: currentStreak.clamp(0, _weeklyMaxStreak),
      ),
      _MissionItem(
        emoji: '📖',
        titleKey: 'missions.weekly.writeDiary',
        reward: '+30 LP',
        isDone: diaryCountThisWeek >= _weeklyMaxDiary,
        progress: '$diaryCountThisWeek/$_weeklyMaxDiary',
        progressMax: _weeklyMaxDiary,
        progressCurrent: diaryCountThisWeek.clamp(0, _weeklyMaxDiary),
      ),
      _MissionItem(
        emoji: '😊',
        titleKey: 'missions.weekly.shareMoodDays',
        reward: '+25 LP',
        isDone: moodDaysThisWeek >= _weeklyMaxMood,
        progress: '$moodDaysThisWeek/$_weeklyMaxMood',
        progressMax: _weeklyMaxMood,
        progressCurrent: moodDaysThisWeek.clamp(0, _weeklyMaxMood),
      ),
      _MissionItem(
        emoji: '💰',
        titleKey: 'missions.weekly.addSavingJar',
        reward: '+20 LP',
        isDone: hasSavingJar,
        isNavigation: !hasSavingJar,
      ),
    ];
  }

  bool _allMissionsDone(List<_MissionItem> daily, List<_MissionItem> weekly) =>
      daily.every((m) => m.isDone) && weekly.every((m) => m.isDone);

  void _claimReward() {
    setState(() {
      _rewardClaimed = true;
      _showConfetti = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showConfetti = false);
    });
  }

  /// Build a lightweight PetMissionEntity from the currently-watched
  /// PetEntity so we can derive `fedToday` / `patPetDoneToday` without
  /// adding a new Firestore stream.
  PetMissionEntity? _deriveMissionEntity(PetEntity? pet) {
    if (pet == null) return null;
    final today = _todayKey();
    return PetMissionEntity(
      coupleId: pet.coupleId,
      feedCount: pet.food,
      patCount: pet.patCountToday,
      lastFeedDate: pet.lastFeedDate,
      lastPatDate: pet.patDate == today ? pet.patDate : null,
    );
  }

  String _todayKey() {
    final d = DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// Returns the start of the current week (Monday) as a DateTime.
  DateTime _weekStart() {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  /// Counts how many diary entries were added this week.
  int _diaryCountThisWeek(List<dynamic> memories) {
    final start = _weekStart();
    return memories.where((m) {
      final dt = _dateTimeOf(m.date);
      return dt != null && !dt.isBefore(start);
    }).length;
  }

  /// Counts how many days this week the user shared a mood.
  int _moodDaysThisWeek(List<dynamic> recentMoods) {
    final start = _weekStart();
    return recentMoods.where((m) {
      final dt = _dateTimeOf(m.date);
      return dt != null && !dt.isBefore(start);
    }).length;
  }

  /// Best-effort DateTime extractor for a memory's `date` field.
  DateTime? _dateTimeOf(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    try {
      final dyn = v as dynamic;
      return dyn.toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }

  /// Best-effort date extractor for a memory's `date` field, which is
  /// a `Timestamp` or `DateTime` depending on where it came from.
  String? _dateKeyOf(dynamic v) {
    DateTime? dt;
    if (v == null) return null;
    if (v is DateTime) {
      dt = v;
    } else if (v is String) {
      // Firestore sometimes serializes to ISO 8601 — try to parse it.
      dt = DateTime.tryParse(v);
    } else {
      // cloud_firestore.Timestamp has .toDate()
      try {
        final dynamic dyn = v;
        final candidate = dyn.toDate() as DateTime?;
        dt = candidate;
      } catch (_) {
        dt = null;
      }
    }
    if (dt == null) return null;
    final m = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    final coupleId = ref.watch(currentCoupleIdProvider);
    final pet = ref.watch(watchPetProvider).valueOrNull;
    // Keep providers alive
    ref.watch(authStateProvider);

    // Streak data for weekly mission
    final streak = ref.watch(watchStreakProvider).valueOrNull;

    // Diary entries this week
    final memories = ref.watch(watchMemoriesProvider).valueOrNull ?? [];

    // Mood days this week (last 14 days covers current week)
    final recentMoods = ref.watch(watchRecentMoodsProvider(14)).valueOrNull ?? [];

    // Saving jars — has at least one jar
    final jars = ref.watch(watchJarsProvider).valueOrNull ?? [];
    final hasSavingJar = jars.isNotEmpty;

    final missionEntity = coupleId == null ? null : _deriveMissionEntity(pet);
    final daily = _dailyMissionsList(missionEntity);

    // Compute weekly mission progress from live data
    final weekly = _weeklyMissionsList(
      streak?.currentStreak ?? 0,
      _diaryCountThisWeek(memories),
      _moodDaysThisWeek(recentMoods),
      hasSavingJar,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  _buildHeader(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildWeeklyProgressCard(weekly),
                  const SizedBox(height: AppSpacing.md),
                  _buildDailyMissions(daily),
                  const SizedBox(height: AppSpacing.md),
                  _buildWeeklyMissions(weekly),
                  const SizedBox(height: AppSpacing.md),
                  _buildSpecialMissions(),
                  const SizedBox(height: AppSpacing.lg),
                  if (_allMissionsDone(daily, weekly) && !_rewardClaimed) _buildClaimButton(),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),

          // Confetti overlay
          if (_showConfetti)
            Positioned.fill(
              child: IgnorePointer(
                child: SizedBox(
                  width: double.infinity, height: double.infinity,
                  child: Lottie.asset(
                    'assets/animations/confetti.json',
                    repeat: false,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _ConfettiFallback(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
        Text('pet.missionsTitle'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const Spacer(),
        Text('pet.missionsResets'.tr(), style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _buildWeeklyProgressCard(List<_MissionItem> weekly) {
    // Count done and total from live weekly missions
    final done = weekly.where((m) => m.isDone).length;
    final total = weekly.length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.1), blurRadius: 12)],
      ),
      child: GlassCard(
        child: Column(
          children: [
            Text('missions.weeklyProgress'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.md),
            Text('missions.missionsCompleted'.tr(namedArgs: {'done': '$done', 'total': '$total'}), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (done / total).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              ).createShader(bounds),
              child: Text(
                'missions.weeklyBonus'.tr(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyMissions(List<_MissionItem> missions) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('pet.dailyMissions'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          ...missions.map((m) => _MissionRow(mission: m)),
        ],
      ),
    );
  }

  Widget _buildWeeklyMissions(List<_MissionItem> weekly) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('pet.weeklyMissions'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          ...weekly.map((m) => _MissionRow(mission: m)),
        ],
      ),
    );
  }

  Widget _buildSpecialMissions() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3), width: 1.5),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('pet.specialMissions'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Text('🎂', style: TextStyle(fontSize: 24)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('missions.special.happyBirthday'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text('pet.unlocksOnBirthday'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text('pet.currentlyLocked'.tr(), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Text('+100 LP', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFFD700))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimButton() {
    return GestureDetector(
      onTap: _claimReward,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: Text('missions.claimReward'.tr(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ),
    )
        .animate()
        .fadeIn()
        .shimmer(duration: const Duration(milliseconds: 1500), color: Colors.white.withValues(alpha: 0.3));
  }
}

// ─── MISSION DATA ─────────────────────────────────────────────────────────────
class _MissionItem {
  const _MissionItem({
    required this.emoji, required this.titleKey, required this.reward,
    required this.isDone, this.progress, this.progressMax, this.progressCurrent,
    this.isNavigation = false,
  });
  final String emoji;
  /// Translation key, e.g. 'missions.daily.bothCheckIn'.
  final String titleKey;
  final String reward;
  final bool isDone;
  final String? progress;
  final int? progressMax;
  final int? progressCurrent;
  final bool isNavigation;
}

// ─── MISSION ROW ──────────────────────────────────────────────────────────────
class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.mission});
  final _MissionItem mission;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              // Emoji circle
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: mission.isDone
                      ? const Color(0xFF2E7D32).withValues(alpha: 0.2)
                      : AppColors.backgroundPrimary,
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(mission.emoji, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.titleKey.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: mission.isDone ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
                    if (mission.progress != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.backgroundPrimary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: ((mission.progressCurrent ?? 0) / (mission.progressMax ?? 1)).clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(mission.progress!, style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.7))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Reward chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(mission.reward, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFFD700))),
              ),
              const SizedBox(width: 8),
              // Status
              if (mission.isDone)
                Container(
                  width: 28, height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('✅', style: TextStyle(fontSize: 14))),
                )
              else if (mission.isNavigation)
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
                )
              else
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── CONFETTI FALLBACK ─────────────────────────────────────────────────────────
class _ConfettiFallback extends StatelessWidget {
  const _ConfettiFallback();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ['💖', '💕', '💗', '✨', '🎉']
          .asMap()
          .entries
          .map((e) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(e.value, style: const TextStyle(fontSize: 28))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(begin: 0, end: -20, delay: Duration(milliseconds: e.key * 80), duration: const Duration(milliseconds: 600)),
              ))
          .toList(),
    );
  }
}
