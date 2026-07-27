import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../../diary/presentation/providers/memory_providers.dart';
import '../../../finance/domain/entities/saving_jar.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../../gamification/presentation/providers/pet_providers.dart';
import '../../../mood/presentation/providers/mood_providers.dart';
import '../../../streak/domain/entities/streak_entity.dart';
import '../../../streak/presentation/providers/streak_providers.dart';
import '../../domain/entities/couple_ai_context.dart';

/// Aggregates a [CoupleAiContext] from the rest of the app, computing
/// upcoming milestones in Dart so the AI never has to do date math.
///
/// Best-effort: any source that hasn't loaded yet is silently omitted. The
/// resulting [CoupleAiContext.contextText] is the text we prepend to the
/// AI's system message.
final coupleAiContextProvider = Provider<CoupleAiContext>((ref) {
  final me = ref.watch(authStateProvider).valueOrNull;
  final partner = ref.watch(partnerProfileProvider).valueOrNull;
  final duration = ref.watch(loveDurationProvider);
  final streak = ref.watch(watchStreakProvider).valueOrNull;
  final moods = ref.watch(watchTodayMoodProvider).valueOrNull;
  final pet = ref.watch(watchPetProvider).valueOrNull;
  final memories = ref.watch(watchMemoriesProvider).valueOrNull;
  final jars = ref.watch(watchJarsProvider).valueOrNull;

  // Start date: prefer the live couple doc, then fall back to daysTogether.
  final coupleId = ref.watch(currentCoupleIdProvider);
  DateTime? startDate;
  if (coupleId != null) {
    final couple = ref.watch(watchCoupleProvider(coupleId)).valueOrNull;
    startDate = couple?.startDate;
  }

  // Pet summary
  PetSummary? petSummary;
  if (pet != null) {
    petSummary = PetSummary(
      level: pet.level,
      hp: pet.hp,
      maxHp: 100,
      lovePoints: pet.lovePoints,
      food: pet.food,
      typeLabel: pet.type.displayName,
    );
  }

  // Jar summaries
  final jarSummaries = (jars ?? const <SavingJar>[])
      .map(
        (j) => JarSummary(
          name: j.name,
          emoji: j.emoji,
          currentAmount: j.currentAmount,
          targetAmount: j.targetAmount,
          deadline: j.deadline,
        ),
      )
      .toList(growable: false);

  // Milestones
  final milestones = _computeMilestones(
    startDate: startDate,
    daysTogether: duration?.days,
    now: DateTime.now(),
  );

  return CoupleAiContext(
    yourName: me?.displayName,
    partnerName: partner?.displayName,
    startDate: startDate,
    daysTogether: duration?.days,
    currentStreak: streak?.currentStreak,
    streakStatusLabel: streak != null ? _streakStatusLabel(streak.status) : null,
    myMood: moods?.mine != null
        ? '${moods!.mine!.emoji} ${moods.mine!.label}'
        : null,
    partnerMood: moods?.partner != null
        ? '${moods!.partner!.emoji} ${moods.partner!.label}'
        : null,
    pet: petSummary,
    jars: jarSummaries,
    memoriesCount: memories?.length,
    milestones: milestones,
  );
});

String _streakStatusLabel(StreakStatus s) {
  switch (s) {
    case StreakStatus.active:
      return 'active today';
    case StreakStatus.atRisk:
      return 'at risk';
    case StreakStatus.broken:
      return 'broken';
    case StreakStatus.idle:
      return 'idle';
  }
}

/// Compute the upcoming milestones list, sorted by date ascending. We only
/// include milestones whose date is on or after [now] (today, inclusive).
///
/// Included: next monthly, plus 100/200/300/500/1000-day marks, plus 1/2/3-year
/// anniversaries. Duplicates (e.g. a 365-day monthly that coincides with the
/// 1-year anniversary) are deduplicated by date.
List<CoupleAiMilestone> _computeMilestones({
  DateTime? startDate,
  int? daysTogether,
  required DateTime now,
}) {
  if (startDate == null) return const <CoupleAiMilestone>[];
  final today = DateTime(now.year, now.month, now.day);
  final out = <CoupleAiMilestone>[];
  final seenDates = <DateTime>{};

  void add(String label, DateTime date) {
    if (date.isBefore(today)) return;
    final day = DateTime(date.year, date.month, date.day);
    if (seenDates.contains(day)) return;
    seenDates.add(day);
    final daysRemaining = day.difference(today).inDays;
    out.add(
      CoupleAiMilestone(
        label: label,
        date: day,
        daysRemaining: daysRemaining,
      ),
    );
  }

  // Day-based milestones (100, 200, 300, 500, 1000)
  for (final n in const [100, 200, 300, 500, 1000]) {
    final date = startDate.add(Duration(days: n));
    add('$n days together', date);
  }

  // Yearly anniversaries (1, 2, 3, 5, 10 years)
  for (final n in const [1, 2, 3, 5, 10]) {
    final date = _addYearsSafe(startDate, n);
    add(
      n == 1 ? '1 year anniversary' : '$n year anniversary',
      date,
    );
  }

  // Next monthly anniversary: the next future month whose day == startDate.day.
  // If we're past the day this month, jump to next month.
  final nextMonthly = _nextMonthlyAnniversary(startDate, today);
  if (nextMonthly != null) {
    final monthsDiff = _monthsBetween(startDate, nextMonthly);
    final label = monthsDiff == 1
        ? '1 month anniversary'
        : '$monthsDiff month anniversary';
    add(label, nextMonthly);
  }

  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

/// Returns the next future month-anniversary (same day-of-month as [start])
/// on or after [today], or `null` if [start].day is invalid for that month.
DateTime? _nextMonthlyAnniversary(DateTime start, DateTime today) {
  final targetDay = start.day;
  // Walk forward one month at a time, starting from this month, until we
  // find a candidate whose day (clamped to month length) is >= today.
  DateTime m = DateTime(today.year, today.month, 1);
  for (int i = 0; i < 24; i++) {
    final lastDay = DateTime(m.year, m.month + 1, 0).day;
    final day = targetDay > lastDay ? lastDay : targetDay;
    final candidate = DateTime(m.year, m.month, day);
    if (!candidate.isBefore(today)) return candidate;
    m = DateTime(m.year, m.month + 1, 1);
  }
  return null;
}

int _monthsBetween(DateTime a, DateTime b) {
  int months = (b.year - a.year) * 12 + (b.month - a.month);
  if (b.day < a.day) months -= 1;
  return months;
}

/// Add [years] to [d], clamping the day if the resulting month is shorter
/// (e.g. Feb 29 → Feb 28 in non-leap years).
DateTime _addYearsSafe(DateTime d, int years) {
  final targetYear = d.year + years;
  final lastDay = DateTime(targetYear, d.month + 1, 0).day;
  final day = d.day > lastDay ? lastDay : d.day;
  return DateTime(targetYear, d.month, day);
}

@visibleForTesting
List<CoupleAiMilestone> debugComputeMilestones({
  DateTime? startDate,
  int? daysTogether,
  DateTime? now,
}) =>
    _computeMilestones(
      startDate: startDate,
      daysTogether: daysTogether,
      now: now ?? DateTime.now(),
    );
