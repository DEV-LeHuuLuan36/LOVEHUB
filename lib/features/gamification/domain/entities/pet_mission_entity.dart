import 'package:flutter/foundation.dart';

/// Per-pet counters that drive the daily Pet Missions UI. Mirrors the
/// existing fields on [PetEntity] (`patCountToday`) and extends with a
/// feed counter that the repository is responsible for writing.
///
/// All date fields are stored as ISO date strings (`yyyy-MM-dd`) so we
/// can answer "did this happen today?" with a string compare without
/// pulling in `DateTime` parsing at the entity boundary.
@immutable
class PetMissionEntity {
  final String coupleId;
  final int feedCount;
  final int patCount;
  final String? lastFeedDate;
  final String? lastPatDate;

  const PetMissionEntity({
    required this.coupleId,
    this.feedCount = 0,
    this.patCount = 0,
    this.lastFeedDate,
    this.lastPatDate,
  });

  /// True when the user fed the pet at least once today.
  bool get fedToday => lastFeedDate == _today;

  /// True when the user petted the pet `maxPatPerDay` or more times
  /// today (so they completed the "Pat Pet" mission).
  bool patPetDoneToday(int maxPatPerDay) =>
      lastPatDate == _today && patCount >= maxPatPerDay;

  /// Single source of truth for the local "today" string. Tests can
  /// override this via [_todayOverride].
  static String get _today => _todayOverride ?? _format(DateTime.now());

  static String? _todayOverride;

  /// Test-only: pin "today" so unit tests can be deterministic.
  @visibleForTesting
  static void setTodayOverride(String? isoDate) => _todayOverride = isoDate;

  static String _format(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
