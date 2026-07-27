import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads / writes the `checkinBackgroundUrl` field on the
/// `couples/{coupleId}` document. Owned by the streak feature so
/// the field's semantics live next to the screen that renders it.
abstract class CheckinBackgroundRemoteDataSource {
  Stream<String?> watchCheckinBackground(String coupleId);
  Future<void> setCheckinBackground(String coupleId, String url);
  Future<void> removeCheckinBackground(String coupleId);
}

class CheckinBackgroundRemoteDataSourceImpl
    implements CheckinBackgroundRemoteDataSource {
  CheckinBackgroundRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  static const _field = 'checkinBackgroundUrl';

  @override
  Stream<String?> watchCheckinBackground(String coupleId) {
    return _firestore
        .doc('couples/$coupleId')
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      final raw = snap.data()?[ _field];
      if (raw is String && raw.isNotEmpty) return raw;
      return null;
    }).handleError((Object e, StackTrace st) {
      // Don't tear down the screen on a transient error; just log.
      // ignore: avoid_print
      print('CHK_BG_DBG_ERR: watch failed: $e');
    });
  }

  @override
  Future<void> setCheckinBackground(String coupleId, String url) async {
    await _firestore.doc('couples/$coupleId').set(
      {_field: url},
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> removeCheckinBackground(String coupleId) async {
    await _firestore.doc('couples/$coupleId').set(
      {_field: FieldValue.delete()},
      SetOptions(merge: true),
    );
  }
}
