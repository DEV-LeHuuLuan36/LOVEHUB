import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/member_location.dart';

/// Talks to Firestore for the couple-location sub-feature.
///
/// Path: locations/{coupleId}/members/{uid}
/// Fields:
///   - lat       (number)
///   - lng       (number)
///   - updatedAt (server timestamp)
abstract class LocationRemoteDataSource {
  Stream<MemberLocation?> watchMemberLocation({
    required String coupleId,
    required String uid,
  });

  Future<void> updateMyLocation({
    required String coupleId,
    required String uid,
    required double lat,
    required double lng,
  });
}

class LocationRemoteDataSourceImpl implements LocationRemoteDataSource {
  LocationRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String coupleId, String uid) {
    return _firestore
        .collection('locations')
        .doc(coupleId)
        .collection('members')
        .doc(uid);
  }

  @override
  Stream<MemberLocation?> watchMemberLocation({
    required String coupleId,
    required String uid,
  }) {
    return _doc(coupleId, uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;

      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      DateTime? updatedAt;
      final rawUpdatedAt = data['updatedAt'];
      if (rawUpdatedAt is Timestamp) {
        updatedAt = rawUpdatedAt.toDate();
      } else if (rawUpdatedAt is Map &&
          rawUpdatedAt['_seconds'] is int) {
        // Defensive fallback if Firestore hands back a raw proto
        // map (rare, but possible on some clients / tests).
        updatedAt = DateTime.fromMillisecondsSinceEpoch(
          (rawUpdatedAt['_seconds'] as int) * 1000 +
              ((rawUpdatedAt['_nanoseconds'] as int?) ?? 0) ~/ 1000000,
        );
      }

      return MemberLocation(lat: lat, lng: lng, updatedAt: updatedAt);
    }).handleError((Object e, StackTrace st) {
      // Never let a stream error tear down the screen — the screen
      // treats `null` as "no stored position yet" and shows a
      // friendly empty state. We log so the issue is debuggable.
      debugPrint('LOCATION_DBG_ERR: watchMemberLocation: $e');
    });
  }

  @override
  Future<void> updateMyLocation({
    required String coupleId,
    required String uid,
    required double lat,
    required double lng,
  }) async {
    await _doc(coupleId, uid).set(
      <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}