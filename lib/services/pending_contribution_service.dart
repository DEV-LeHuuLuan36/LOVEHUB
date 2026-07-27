import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/finance/data/models/pending_contribution_model.dart';
import '../features/finance/domain/entities/pending_contribution.dart';

/// Service that creates a pending contribution, listens for its confirmation,
/// and applies it to the jar once confirmed — all without polluting the UI layer
/// with Firestore logic.
class PendingContributionService {
  PendingContributionService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final _rng = Random.secure();

  CollectionReference<Map<String, dynamic>> get _pendingCol =>
      _firestore.collection('pendingContributions');

  DocumentReference<Map<String, dynamic>> _pendingDoc(String code) =>
      _pendingCol.doc(code);

  CollectionReference<Map<String, dynamic>> _contribsCol(
    String coupleId,
    String jarId,
  ) =>
      _firestore
          .collection('savingJars')
          .doc(coupleId)
          .collection('jars')
          .doc(jarId)
          .collection('contributions');

  DocumentReference<Map<String, dynamic>> _jarDoc(String coupleId, String jarId) =>
      _firestore
          .collection('savingJars')
          .doc(coupleId)
          .collection('jars')
          .doc(jarId);

  /// Generates a unique transfer code: "LH" + 6 uppercase alphanumeric chars.
  /// Format: /LH[A-Z0-9]{6}/
  String generateCode() {
    final suffix = List.generate(
      6,
      (_) => _chars[_rng.nextInt(_chars.length)],
    ).join();
    return 'LH$suffix';
  }

  /// Creates a pending contribution document in Firestore and returns its code.
  Future<String> createPending({
    required String code,
    required String jarId,
    required String coupleId,
    required String byUid,
    required String byName,
    required int amount,
  }) async {
    final doc = _pendingDoc(code);
    await doc.set({
      'code': code,
      'jarId': jarId,
      'coupleId': coupleId,
      'byUid': byUid,
      'byName': byName,
      'amount': amount,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'applied': false,
    });
    return code;
  }

  /// Returns a stream of PendingContribution snapshots for the given code.
  /// Emits the current value immediately, then each subsequent change.
  Stream<PendingContribution> watchPending(String code) {
    return _pendingDoc(code).snapshots().map((snap) {
      if (!snap.exists) {
        return PendingContribution(
          code: code,
          jarId: '',
          coupleId: '',
          byUid: '',
          byName: '',
          amount: 0,
          status: 'gone',
          createdAt: DateTime.now(),
        );
      }
      return PendingContributionModel.fromFirestore(code, snap.data()!);
    });
  }

  /// Marks the pending doc as applied AND records the contribution in the jar.
  Future<bool> applyToJar({
    required String code,
    required String jarId,
    required String coupleId,
    required String byUid,
    required String byName,
    required int amount,
  }) async {
    final pendingRef = _pendingDoc(code);
    final jarRef = _jarDoc(coupleId, jarId);
    final contribRef = _contribsCol(coupleId, jarId).doc();

    try {
      await _firestore.runTransaction((tx) async {
        final pendingSnap = await tx.get(pendingRef);
        if (!pendingSnap.exists) {
          throw Exception('Pending contribution not found');
        }
        final pending = PendingContributionModel.fromFirestore(
          code,
          pendingSnap.data()!,
        );

        // Defensive: skip if already applied or not confirmed
        if (pending.applied || pending.status != 'confirmed') {
          throw Exception('Cannot apply: status=$pending.status applied=$pending.applied');
        }

        final now = DateTime.now();

        // Record the contribution under the jar
        tx.set(contribRef, {
          'userId': byUid,
          'userName': byName,
          'amount': amount,
          'method': 'qr',
          'source': 'qr',
          'note': 'SePay auto-confirm',
          'coupleId': coupleId,
          'jarId': jarId,
          'createdAt': now,
        });

        // Update jar currentAmount
        final jarSnap = await tx.get(jarRef);
        final current = (jarSnap.data()?['currentAmount'] as num?)?.toInt() ?? 0;
        tx.update(jarRef, {'currentAmount': current + amount});

        // Mark as applied to prevent double-counting
        tx.update(pendingRef, {'applied': true});
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deletes a pending contribution document (user cancelled).
  Future<void> cancelPending(String code) async {
    await _pendingDoc(code).delete();
  }

  /// Marks a pending contribution as expired so a late transfer won't apply.
  Future<void> markExpired(String code) async {
    await _pendingDoc(code).update({'status': 'expired'});
  }

  /// Returns true if the pending doc has applied == true (already processed by
  /// another process/device). Used to distinguish "already recorded" from "real
  /// failure" when applyToJar returns false.
  Future<bool> isAlreadyApplied(String code) async {
    final snap = await _pendingDoc(code).get();
    return snap.data()?['applied'] == true;
  }
}
