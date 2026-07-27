import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../models/couple_model.dart';

abstract class CoupleRemoteDataSource {
  Future<CoupleModel> createCouple(String userId);
  Future<CoupleModel> joinCouple(String userId, String code);
  Future<void> updateStartDate(String coupleId, DateTime date);
  Future<void> requestUnlink(String coupleId, String userId);
  Future<void> recoverCouple(String coupleId);
  Future<void> finalizeUnlinkIfExpired(String coupleId);
  Stream<CoupleModel?> watchCouple(String coupleId);
}

class CoupleRemoteDataSourceImpl implements CoupleRemoteDataSource {
  CoupleRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;
  static final _random = Random();

  static const _safeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  String _generateCode() {
    final buf = StringBuffer();
    for (int i = 0; i < 8; i++) {
      buf.write(_safeAlphabet[_random.nextInt(_safeAlphabet.length)]);
    }
    final raw = buf.toString();
    return 'LOVE-${raw.substring(0, 4)}-${raw.substring(4)}';
  }

  @override
  Future<CoupleModel> createCouple(String userId) async {
    final couplesRef = _firestore.collection('couples');

    String uniqueCode = '';
    bool found = false;
    for (int attempt = 0; attempt < 5; attempt++) {
      final candidate = _generateCode();
      final snapshot = await couplesRef.where('code', isEqualTo: candidate).limit(1).get();
      if (snapshot.docs.isEmpty) {
        uniqueCode = candidate;
        found = true;
        break;
      }
    }
    if (!found) {
      throw AuthException('Failed to create code, try again');
    }

    final coupleRef = couplesRef.doc();
    final expiresAt = DateTime.now().add(const Duration(hours: 24));

    await _firestore.runTransaction((tx) async {
      tx.set(coupleRef, {
        'code': uniqueCode,
        'user1Id': userId,
        'user2Id': null,
        'status': 'waiting',
        'expiresAt': Timestamp.fromDate(expiresAt),
        'startDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(
        _firestore.doc(FirestorePaths.user(userId)),
        {'coupleId': coupleRef.id},
      );
    });

    final doc = await _firestore.doc('couples/${coupleRef.id}').get();
    if (!doc.exists) throw AuthException('Failed to create couple');
    return CoupleModel.fromFirestore(doc);
  }

  @override
  Future<CoupleModel> joinCouple(String userId, String rawCode) async {
    final normalized = rawCode.toUpperCase().replaceAll(RegExp(r'[\-\s]'), '');
    if (normalized.length != 12) {
      throw AuthException('Invalid code format (12 characters)');
    }
    if (!normalized.startsWith('LOVE')) {
      throw AuthException('Code must start with LOVE');
    }

    final formattedCode = 'LOVE-${normalized.substring(4, 8)}-${normalized.substring(8)}';

    final snapshot = await _firestore
        .collection('couples')
        .where('code', isEqualTo: formattedCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw AuthException('Code not found');
    }

    final docSnap = snapshot.docs.first;
    final data = docSnap.data();
    final docRef = docSnap.reference;

    if (data['status'] != 'waiting') {
      throw AuthException('Code already used');
    }
    if (data['user2Id'] != null) {
      throw AuthException('Code already used');
    }
    if (data['expiresAt'] != null) {
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        throw AuthException('Code expired');
      }
    }
    if (data['user1Id'] == userId) {
      throw AuthException("You can't pair with yourself");
    }

    await _firestore.runTransaction((tx) async {
      tx.update(docRef, {'user2Id': userId, 'status': 'linked'});
      tx.update(
        _firestore.doc(FirestorePaths.user(userId)),
        {'coupleId': docRef.id},
      );
      final user1Id = data['user1Id'] as String;
      tx.update(
        _firestore.doc(FirestorePaths.user(user1Id)),
        {'coupleId': docRef.id},
      );
    });

    final doc = await _firestore.doc('couples/${docRef.id}').get();
    if (!doc.exists) throw AuthException('Cannot complete pairing');
    return CoupleModel.fromFirestore(doc);
  }

  @override
  Stream<CoupleModel?> watchCouple(String coupleId) {
    return _firestore.doc('couples/$coupleId').snapshots().map((doc) {
      if (!doc.exists) return null;
      return CoupleModel.fromFirestore(doc);
    });
  }

  @override
  Future<void> updateStartDate(String coupleId, DateTime date) async {
    await _firestore.doc('couples/$coupleId').update({
      'startDate': Timestamp.fromDate(date),
    });
  }

  @override
  Future<void> requestUnlink(String coupleId, String userId) async {
    await _firestore.doc('couples/$coupleId').update({
      'status': 'pending_unlink',
      'unlinkRequestedAt': Timestamp.now(),
      'unlinkRequestedBy': userId,
    });
  }

  @override
  Future<void> recoverCouple(String coupleId) async {
    await _firestore.doc('couples/$coupleId').update({
      'status': 'linked',
      'unlinkRequestedAt': null,
      'unlinkRequestedBy': null,
    });
  }

  @override
  Future<void> finalizeUnlinkIfExpired(String coupleId) async {
    await _firestore.runTransaction((tx) async {
      final docSnap = await tx.get(_firestore.doc('couples/$coupleId'));
      if (!docSnap.exists) return;

      final data = docSnap.data()!;
      if (data['status'] != 'pending_unlink') return;

      final requestedAt = data['unlinkRequestedAt'];
      if (requestedAt == null) return;

      final deadline = (requestedAt as Timestamp).toDate().add(const Duration(days: 3));
      if (DateTime.now().isBefore(deadline)) return;

      // Expired — set unlinked and clear both users' coupleId
      tx.update(docSnap.reference, {'status': 'unlinked'});
      final user1Id = data['user1Id'] as String?;
      final user2Id = data['user2Id'] as String?;
      if (user1Id != null) {
        tx.update(_firestore.doc(FirestorePaths.user(user1Id)), {'coupleId': null});
      }
      if (user2Id != null) {
        tx.update(_firestore.doc(FirestorePaths.user(user2Id)), {'coupleId': null});
      }
    });
  }
}
