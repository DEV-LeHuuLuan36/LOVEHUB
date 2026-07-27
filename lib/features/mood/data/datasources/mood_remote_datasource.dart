import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/mood_entry.dart';
import '../../domain/repositories/mood_repository.dart';
import '../models/mood_entry_model.dart';

abstract class MoodRemoteDataSource {
  Stream<DailyMood> watchTodayMood(String coupleId, String myUid, String partnerUid);
  Stream<List<DailyMood>> watchRecentMoods(
    String coupleId, {
    required String myUid,
    required String partnerUid,
    int days = 14,
  });
  Future<SetMoodResult> setMood({
    required String coupleId,
    required String uid,
    required String emoji,
    required String label,
    String? note,
  });
}

class MoodRemoteDataSourceImpl implements MoodRemoteDataSource {
  MoodRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('moods');

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  DocumentReference<Map<String, dynamic>> _todayDoc(String coupleId) {
    return _col.doc(coupleId).collection('daily').doc(_todayStr());
  }

  DocumentReference<Map<String, dynamic>> _petDoc(String coupleId) {
    return _firestore.collection('pets').doc(coupleId);
  }

  @override
  Stream<DailyMood> watchTodayMood(String coupleId, String myUid, String partnerUid) {
    final today = _todayStr();
    return _todayDoc(coupleId).snapshots().map((snap) {
      if (!snap.exists) {
        return DailyMood(date: today);
      }
      final entries = snap.data()!['entries'] as Map<String, dynamic>? ?? {};
      return _dailyFromEntries(today, entries, myUid, partnerUid);
    });
  }

  @override
  Stream<List<DailyMood>> watchRecentMoods(
    String coupleId, {
    required String myUid,
    required String partnerUid,
    int days = 14,
  }) {
    // Doc IDs are zero-padded yyyy-MM-dd, so lex sort == date sort.
    // `orderBy('__name__', descending: true)` gives newest first.
    final query = _col
        .doc(coupleId)
        .collection('daily')
        .orderBy('__name__', descending: true)
        .limit(days);
    return query.snapshots().map((snap) {
      return snap.docs
          .map((doc) => _dailyFromEntries(
                doc.id,
                doc.data()['entries'] as Map<String, dynamic>? ?? const {},
                myUid,
                partnerUid,
              ))
          .toList(growable: false);
    }).handleError((Object e, StackTrace st) {
      // Never let a stream error tear down the screen — log and emit
      // an empty list. The user will see the empty state and can
      // retry by re-opening the screen.
      // ignore: avoid_print
      print('MOOD_DBG_ERR: watchRecentMoods: $e');
    });
  }

  DailyMood _dailyFromEntries(
    String date,
    Map<String, dynamic> entries,
    String myUid,
    String partnerUid,
  ) {
    MoodEntry? mine;
    MoodEntry? partner;
    final mineRaw = entries[myUid];
    if (mineRaw is Map) {
      mine = MoodEntryModel.fromFirestore(myUid, mineRaw.cast<String, dynamic>());
    }
    final partnerRaw = entries[partnerUid];
    if (partnerRaw is Map) {
      partner = MoodEntryModel.fromFirestore(
        partnerUid,
        partnerRaw.cast<String, dynamic>(),
      );
    }
    return DailyMood(date: date, mine: mine, partner: partner);
  }

  @override
  Future<SetMoodResult> setMood({
    required String coupleId,
    required String uid,
    required String emoji,
    required String label,
    String? note,
  }) async {
    final moodDocRef = _todayDoc(coupleId);
    final petDocRef = _petDoc(coupleId);

    return await _firestore.runTransaction((tx) async {
      // READS first
      final snap = await tx.get(moodDocRef);
      final data = snap.data();
      final entries = data?['entries'] as Map<String, dynamic>? ?? {};

      final firstToday = !entries.containsKey(uid);
      final now = FieldValue.serverTimestamp();

      // Only read pet if we might award LP — but reads must come before all
      // writes, so we read it conditionally via local logic. Since the only
      // write that depends on the pet read is the LP update, and we have to
      // do all reads before all writes, we read the pet here regardless of
      // firstToday. The cost is one extra read in the common case.
      int? newLp;
      if (firstToday) {
        final petSnap = await tx.get(petDocRef);
        if (petSnap.exists) {
          final currentLp = (petSnap.data()!['lovePoints'] as num?)?.toInt() ?? 0;
          newLp = currentLp + 5;
        }
      }

      // WRITES after reads
      final newEntry = <String, dynamic>{
        'emoji': emoji,
        'label': label,
        'note': note,
        'updatedAt': now,
      };

      tx.set(moodDocRef, {'entries': {uid: newEntry}}, SetOptions(merge: true));

      if (firstToday && newLp != null) {
        tx.update(petDocRef, {'lovePoints': newLp});
      }

      return SetMoodResult(lpAwarded: firstToday, firstToday: firstToday);
    });
  }
}
