import 'package:flutter/foundation.dart';

/// Daily AI usage counter for a couple, persisted under
/// `aiUsage/{coupleId}` (single doc, fields: `date`, `count`).
///
/// The date is the local-day string `yyyy-MM-dd`; whenever a new request
/// comes in on a different day, the counter resets to 0.
@immutable
class AiUsage {
  const AiUsage({
    required this.date,
    required this.count,
  });

  /// `yyyy-MM-dd` of the local day this counter applies to.
  final String date;
  final int count;

  static const int dailyLimit = 20;

  /// Parses a Firestore doc snapshot into an [AiUsage].
  ///
  /// If [today] is supplied (default `yyyy-MM-dd` from local `DateTime.now()`),
  /// a stale doc (date != today) is treated as 0 for today — this is the key
  /// fix for the "counter never resets until first question" bug: the stream
  /// must return the logically-correct count even when the user hasn't asked
  /// anything yet.
  ///
  /// Returns `null` when `data` is `null` or has no `date` field.
  static AiUsage? fromMap(Map<String, dynamic>? data, {String? today}) {
    if (data == null) return null;
    final storedDate = data['date'] as String?;
    if (storedDate == null) return null;
    final todayDate = today ?? _localToday();
    // Stale date (yesterday or older) → treat as fresh 0 for today.
    if (storedDate != todayDate) {
      return AiUsage(date: todayDate, count: 0);
    }
    final count = (data['count'] as num?)?.toInt() ?? 0;
    return AiUsage(date: storedDate, count: count < 0 ? 0 : count);
  }

  static String _localToday() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  /// `dailyLimit - count`, never negative. `null` if [count] is null
  /// (caller should treat null as "no usage record yet → 20 left").
  int get remaining {
    final left = dailyLimit - count;
    return left < 0 ? 0 : left;
  }

  bool get isAtLimit => count >= dailyLimit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiUsage && date == other.date && count == other.count;

  @override
  int get hashCode => Object.hash(date, count);
}
