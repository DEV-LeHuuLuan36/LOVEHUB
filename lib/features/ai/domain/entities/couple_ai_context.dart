import 'package:flutter/foundation.dart';

/// A single upcoming milestone computed in Dart (not by the AI).
@immutable
class CoupleAiMilestone {
  const CoupleAiMilestone({
    required this.label,
    required this.date,
    required this.daysRemaining,
  });

  /// Human-readable label, e.g. "1 year anniversary", "100 days together".
  final String label;

  /// The date of the milestone (year/month/day only — time-of-day not relevant).
  final DateTime date;

  /// `date` minus today, floored to whole days. Always non-negative.
  final int daysRemaining;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoupleAiMilestone &&
          label == other.label &&
          date == other.date &&
          daysRemaining == other.daysRemaining;

  @override
  int get hashCode => Object.hash(label, date, daysRemaining);
}

/// Compact summary of the couple's pet, as exposed to the AI.
@immutable
class PetSummary {
  const PetSummary({
    required this.level,
    required this.hp,
    required this.maxHp,
    required this.lovePoints,
    required this.food,
    this.typeLabel,
  });

  final int level;
  final int hp;
  final int maxHp;
  final int lovePoints;
  final int food;
  final String? typeLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetSummary &&
          level == other.level &&
          hp == other.hp &&
          maxHp == other.maxHp &&
          lovePoints == other.lovePoints &&
          food == other.food &&
          typeLabel == other.typeLabel;

  @override
  int get hashCode =>
      Object.hash(level, hp, maxHp, lovePoints, food, typeLabel);
}

/// Compact summary of one saving jar, as exposed to the AI.
@immutable
class JarSummary {
  const JarSummary({
    required this.name,
    required this.emoji,
    required this.currentAmount,
    required this.targetAmount,
    this.deadline,
  });

  final String name;
  final String emoji;
  final int currentAmount;
  final int targetAmount;
  final DateTime? deadline;

  /// 0.0..1.0 (0 if targetAmount is 0).
  double get progress {
    if (targetAmount <= 0) return 0;
    final p = currentAmount / targetAmount;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  int get percentInt => (progress * 100).round();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JarSummary &&
          name == other.name &&
          emoji == other.emoji &&
          currentAmount == other.currentAmount &&
          targetAmount == other.targetAmount &&
          deadline == other.deadline;

  @override
  int get hashCode =>
      Object.hash(name, emoji, currentAmount, targetAmount, deadline);
}

/// The structured, precomputed snapshot of couple data that the AI needs in
/// order to answer data-aware questions.
///
/// All numeric facts (days together, days until milestone, streak length,
/// etc.) are computed in Dart and passed to the AI verbatim — the model is
/// explicitly told NOT to recompute dates from raw inputs.
@immutable
class CoupleAiContext {
  const CoupleAiContext({
    this.yourName,
    this.partnerName,
    this.startDate,
    this.daysTogether,
    this.currentStreak,
    this.streakStatusLabel,
    this.myMood,
    this.partnerMood,
    this.pet,
    this.jars = const <JarSummary>[],
    this.memoriesCount,
    this.milestones = const <CoupleAiMilestone>[],
  });

  final String? yourName;
  final String? partnerName;
  final DateTime? startDate;
  final int? daysTogether;
  final int? currentStreak;
  final String? streakStatusLabel;
  final String? myMood;
  final String? partnerMood;
  final PetSummary? pet;
  final List<JarSummary> jars;
  final int? memoriesCount;
  final List<CoupleAiMilestone> milestones;

  /// `true` when we have at least one piece of data about the couple.
  bool get hasAnyData =>
      yourName != null ||
      partnerName != null ||
      daysTogether != null ||
      currentStreak != null ||
      myMood != null ||
      partnerMood != null ||
      pet != null ||
      jars.isNotEmpty ||
      (memoriesCount ?? 0) > 0 ||
      milestones.isNotEmpty;

  /// Empty context — useful for tests and as a default.
  static const CoupleAiContext empty = CoupleAiContext();

  /// Build a compact, readable text block for injecting into the AI prompt.
  /// Sections are omitted when the corresponding data is unavailable.
  String get contextText {
    final b = StringBuffer();
    b.writeln('Couple snapshot (already computed in app — trust these numbers):');

    // Names
    final you = yourName;
    final partner = partnerName;
    if (you != null && partner != null) {
      b.writeln('- Couple: $you and $partner');
    } else if (you != null) {
      b.writeln('- You: $you');
    } else if (partner != null) {
      b.writeln("- Partner: $partner");
    }

    // Days together + start date
    final days = daysTogether;
    if (days != null) {
      final start = startDate;
      if (start != null) {
        b.writeln('- Started: ${_formatDate(start)}');
      }
      b.writeln('- Days together: $days');
    }

    // Streak
    if (currentStreak != null) {
      final status = streakStatusLabel;
      final tail = (status != null && status.isNotEmpty) ? ' ($status)' : '';
      b.writeln('- Current streak: $currentStreak days$tail');
    }

    // Moods
    if (myMood != null) {
      b.writeln("- Your mood today: $myMood");
    }
    if (partnerMood != null) {
      b.writeln("- Partner's mood today: $partnerMood");
    }

    // Pet
    final p = pet;
    if (p != null) {
      final type = p.typeLabel != null ? ' (${p.typeLabel})' : '';
      b.writeln(
        '- Pet$type: level ${p.level}, HP ${p.hp}/${p.maxHp}, '
        'love points ${p.lovePoints}, food ${p.food}',
      );
    }

    // Jars
    if (jars.isNotEmpty) {
      b.writeln('- Saving jars:');
      for (final j in jars) {
        b.writeln('  - ${j.emoji} ${j.name}: ${j.percentInt}% '
            '(${j.currentAmount}/${j.targetAmount})');
      }
    }

    // Memories
    if (memoriesCount != null) {
      b.writeln('- Memories saved: $memoriesCount');
    }

    // Milestones — the precomputed days-until values
    if (milestones.isNotEmpty) {
      b.writeln('- Upcoming milestones (use these days-remaining values, '
          'do NOT recalculate):');
      for (final m in milestones) {
        b.writeln('  - ${m.label}: ${_formatDate(m.date)} '
            '(${m.daysRemaining} day${m.daysRemaining == 1 ? '' : 's'} from today)');
      }
    }

    return b.toString().trimRight();
  }

  static String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoupleAiContext &&
          yourName == other.yourName &&
          partnerName == other.partnerName &&
          startDate == other.startDate &&
          daysTogether == other.daysTogether &&
          currentStreak == other.currentStreak &&
          streakStatusLabel == other.streakStatusLabel &&
          myMood == other.myMood &&
          partnerMood == other.partnerMood &&
          pet == other.pet &&
          listEquals(jars, other.jars) &&
          memoriesCount == other.memoriesCount &&
          listEquals(milestones, other.milestones);

  @override
  int get hashCode => Object.hash(
        yourName,
        partnerName,
        startDate,
        daysTogether,
        currentStreak,
        streakStatusLabel,
        myMood,
        partnerMood,
        pet,
        Object.hashAll(jars),
        memoriesCount,
        Object.hashAll(milestones),
      );
}
