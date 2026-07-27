import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/streak_model.dart';
import '../../domain/entities/streak_entity.dart';

abstract class StreakRemoteDataSource {
  Stream<StreakModel> watchStreak({
    required String coupleId,
    required String myUid,
    required String partnerId,
  });

  Future<StreakModel> checkIn({
    required String coupleId,
    required String myUid,
    required String partnerId,
  });

  Future<StreakModel> useRecoveryToken({
    required String coupleId,
    required String myUid,
    required String partnerId,
  });
}

class StreakRemoteDataSourceImpl implements StreakRemoteDataSource {
  StreakRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('streaks');

  @override
  Stream<StreakModel> watchStreak({
    required String coupleId,
    required String myUid,
    required String partnerId,
  }) {
    return _col.doc(coupleId).snapshots().map((snap) {
      if (!snap.exists) return StreakModel.empty(partnerId);
      return StreakModel.fromFirestore(snap.data()!, myUid, partnerId);
    });
  }

  @override
  Future<StreakModel> checkIn({
    required String coupleId,
    required String myUid,
    required String partnerId,
  }) async {
    final docRef = _col.doc(coupleId);
    final today = StreakEntity.todayStr();
    final yesterday = StreakEntity.yesterdayStr();

    debugPrint(
      'CHECKIN_DBG: checkIn START — coupleId=$coupleId, myUid=$myUid, '
      'partnerId=$partnerId, today=$today',
    );

    final result = await _firestore.runTransaction((tx) async {
      // ── All reads must happen before any writes in a Firestore
      //    transaction. The previous implementation did a `tx.get`
      //    after a `tx.set`, which is rejected by the SDK (the
      //    transaction aborts and the write never lands, so the
      //    UI never updated after Check In).
      final snap = await tx.get(docRef);
      debugPrint(
        'CHECKIN_DBG: pre-write snapshot exists=${snap.exists}, '
        'dataKeys=${snap.data()?.keys.toList()}',
      );

      final raw = snap.data() ?? const <String, dynamic>{};
      final current = StreakModel.fromFirestore(raw, myUid, partnerId);
      debugPrint(
        'CHECKIN_DBG: current state — meChecked=${current.meCheckedToday}, '
        'partnerChecked=${current.partnerCheckedToday}, '
        'streak=${current.currentStreak}, '
        'lastComplete=${current.lastCompleteDate}, '
        'tokens=${current.recoveryTokens}',
      );

      // Simulate the post-write state in Dart so we never need to
      // re-read inside the transaction. The new checkins map adds
      // this user to today's bucket; everything else is left alone.
      final rawCheckins = raw['checkins'] as Map<String, dynamic>? ?? {};
      final newCheckins = <String, dynamic>{
        for (final entry in rawCheckins.entries) entry.key: entry.value,
        today: <String, dynamic>{
          ...(rawCheckins[today] as Map<String, dynamic>? ?? const {}),
          myUid: true,
        },
      };

      final partnerCheckedNow = current.partnerCheckedToday;
      final meCheckedNow = true; // we're about to flip this on
      final bothNow = meCheckedNow && partnerCheckedNow;
      debugPrint(
        'CHECKIN_DBG: simulated post-write — meChecked=$meCheckedNow, '
        'partnerChecked=$partnerCheckedNow, both=$bothNow',
      );

      // ── Build the new streak/tokens/lastCompleteDate in Dart.
      int newStreak = current.currentStreak;
      String? newLastCompleteDate = current.lastCompleteDate;
      int newTokens = current.recoveryTokens;
      int newLastTokenStreak =
          (raw['lastTokenStreak'] as int?) ?? 0;

      if (bothNow) {
        if (current.lastCompleteDate == yesterday) {
          newStreak = current.currentStreak + 1;
        } else if (current.lastCompleteDate == today) {
          newStreak = current.currentStreak;
        } else {
          newStreak = 1;
        }
        newLastCompleteDate = today;

        // Award a recovery shield for every 15 consecutive
        // check-in days. After awarding, the 15-day counter
        // resets (via `newLastTokenStreak = newStreak`) so the
        // next shield is earned at +15 from the previous one.
        // Capped at 4 shields — if we're already at the cap we
        // keep the streak going but skip the increment. The
        // `broken` branch below resets `lastTokenStreak` so that
        // a fresh 15-day streak after a break yields a new
        // shield (progress toward the next shield resets with
        // the streak itself).
        if (newStreak > 0 &&
            newStreak % 15 == 0 &&
            newStreak > newLastTokenStreak &&
            newTokens < 4) {
          newTokens = current.recoveryTokens + 1;
          newLastTokenStreak = newStreak;
        }
      }

      // Detect "streak just broke" (we checked in, partner did not,
      // and yesterday was a complete day but today+1 would miss).
      // The original code only wrote `brokenAt` when *both* uncheck
      // — we keep that semantics.
      final neitherNow = !(current.meCheckedToday || partnerCheckedNow);
      final broken = neitherNow &&
          current.lastCompleteDate != null &&
          current.lastCompleteDate != today &&
          current.lastCompleteDate != yesterday &&
          raw['brokenAt'] == null;

      // ── All writes, no more reads.
      final write = <String, dynamic>{
        'checkins': newCheckins,
        if (bothNow) ...{
          'currentStreak': newStreak,
          'lastCompleteDate': newLastCompleteDate,
          if (newTokens != current.recoveryTokens)
            'recoveryTokens': newTokens,
          if (newLastTokenStreak != (raw['lastTokenStreak'] ?? 0))
            'lastTokenStreak': newLastTokenStreak,
        },
        if (broken) ...{
          'currentStreak': 0,
          'streakBeforeBreak': current.currentStreak,
          // Progress toward the next shield resets together with
          // the streak itself — a fresh 15-day streak after the
          // break is enough to earn the next shield.
          'lastTokenStreak': 0,
          'brokenAt': FieldValue.serverTimestamp(),
        },
      };
      tx.set(docRef, write, SetOptions(merge: true));
      debugPrint(
        'CHECKIN_DBG: post-write payload — keys=${write.keys.toList()}, '
        'newStreak=$newStreak, newLastComplete=$newLastCompleteDate, '
        'newTokens=$newTokens, broken=$broken',
      );

      if (bothNow) {
        _awardLovePoints(tx, coupleId, newStreak, true);
      }

      // ── Return the post-write model so the caller sees the new
      //    state immediately, even before the stream emits.
      final merged = <String, dynamic>{
        ...raw,
        'checkins': newCheckins,
        if (bothNow) ...{
          'currentStreak': newStreak,
          'lastCompleteDate': newLastCompleteDate,
          'recoveryTokens': newTokens,
          'lastTokenStreak': newLastTokenStreak,
        },
        if (broken) ...{
          'currentStreak': 0,
          'streakBeforeBreak': current.currentStreak,
          'lastTokenStreak': 0,
        },
      };
      final updated = StreakModel.fromFirestore(merged, myUid, partnerId);
      debugPrint(
        'CHECKIN_DBG: post-write model — meChecked=${updated.meCheckedToday}, '
        'partnerChecked=${updated.partnerCheckedToday}, '
        'streak=${updated.currentStreak}',
      );
      return updated;
    });

    debugPrint('CHECKIN_DBG: checkIn OK — ${result.meCheckedToday}');
    return result;
  }

  @override
  Future<StreakModel> useRecoveryToken({
    required String coupleId,
    required String myUid,
    required String partnerId,
  }) async {
    final docRef = _col.doc(coupleId);
    final yesterday = StreakEntity.yesterdayStr();

    final result = await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw StreakException('Streak not found');

      final current = StreakModel.fromFirestore(snap.data()!, myUid, partnerId);

      if (current.status != StreakStatus.broken) {
        throw StreakException('Streak has not been broken');
      }
      if (current.recoveryTokens <= 0) {
        throw StreakException('No recovery tokens left');
      }
      if (current.brokenAt != null) {
        final elapsed = DateTime.now().difference(current.brokenAt!);
        if (elapsed.inHours > 48) {
          throw StreakException('48-hour recovery window has passed');
        }
      }

      tx.update(docRef, {
        'currentStreak': current.streakBeforeBreak,
        'lastCompleteDate': yesterday,
        'recoveryTokens': current.recoveryTokens - 1,
        'streakBeforeBreak': 0,
        'brokenAt': null,
      });

      return StreakModel.fromFirestore(
        {
          ...snap.data()!,
          'currentStreak': current.streakBeforeBreak,
          'lastCompleteDate': yesterday,
          'recoveryTokens': current.recoveryTokens - 1,
          'streakBeforeBreak': 0,
          'brokenAt': null,
        },
        myUid,
        partnerId,
      );
    });

    return result;
  }

  CollectionReference<Map<String, dynamic>> get _petsCol =>
      _firestore.collection('pets');

  void _awardLovePoints(Transaction tx, String coupleId, int newStreak, bool bothCheckedTodayNow) {
    final today = StreakEntity.todayStr();
    int lpAmount = 10;
    int foodAmount = 0;

    if (newStreak > 0 && newStreak % 7 == 0) {
      lpAmount += 50;
      foodAmount += 3;
    }

    if (bothCheckedTodayNow) {
      foodAmount += 1;
    }

    if (foodAmount > 0) {
      tx.set(
        _petsCol.doc(coupleId),
        {
          'lovePoints': FieldValue.increment(lpAmount),
          'food': FieldValue.increment(foodAmount),
          'lastFoodAwardDate': today,
        },
        SetOptions(merge: true),
      );
    } else {
      tx.set(
        _petsCol.doc(coupleId),
        {'lovePoints': FieldValue.increment(lpAmount)},
        SetOptions(merge: true),
      );
    }
  }
}
