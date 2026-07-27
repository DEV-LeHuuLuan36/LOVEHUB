import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/contribution.dart';
import '../../domain/entities/saving_jar.dart';
import '../models/contribution_model.dart';
import '../models/saving_jar_model.dart';

abstract class FinanceRemoteDataSource {
  Stream<List<SavingJar>> watchJars(String coupleId);
  Stream<List<Contribution>> watchContributions(String coupleId, String jarId);

  Future<void> createJar({
    required String coupleId,
    required String name,
    required String emoji,
    required int targetAmount,
    DateTime? deadline,
    int initialDeposit,
    String? bankCode,
    String? bankAccountNumber,
    String? bankAccountName,
  });

  Future<void> contribute({
    required String coupleId,
    required String jarId,
    required String userId,
    required String userName,
    required int amount,
    String? note,
    required String method,
  });

  Future<void> deleteJar({required String coupleId, required String jarId});
}

class FinanceRemoteDataSourceImpl implements FinanceRemoteDataSource {
  FinanceRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _jarsCol(String coupleId) =>
      _firestore.collection('savingJars').doc(coupleId).collection('jars');

  DocumentReference<Map<String, dynamic>> _jarDoc(String coupleId, String jarId) =>
      _jarsCol(coupleId).doc(jarId);

  CollectionReference<Map<String, dynamic>> _contribsCol(
    String coupleId,
    String jarId,
  ) =>
      _jarDoc(coupleId, jarId).collection('contributions');

  @override
  Stream<List<SavingJar>> watchJars(String coupleId) {
    return _jarsCol(coupleId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SavingJarModel.fromFirestore(doc.id, doc.data()))
            .toList())
        .handleError((Object e, StackTrace st) => throw e);
  }

  @override
  Stream<List<Contribution>> watchContributions(
    String coupleId,
    String jarId,
  ) {
    return _contribsCol(coupleId, jarId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ContributionModel.fromFirestore(doc.id, doc.data()))
            .toList())
        .handleError((Object e, StackTrace st) => throw e);
  }

  @override
  Future<void> createJar({
    required String coupleId,
    required String name,
    required String emoji,
    required int targetAmount,
    DateTime? deadline,
    int initialDeposit = 0,
    String? bankCode,
    String? bankAccountNumber,
    String? bankAccountName,
  }) async {
    if (targetAmount <= 0) {
      throw AuthException('Invalid target amount');
    }
    if (initialDeposit < 0) {
      throw AuthException('Invalid amount');
    }

    final jarRef = _jarsCol(coupleId).doc();
    final contribRef = initialDeposit > 0
        ? jarRef.collection('contributions').doc()
        : null;

    final now = DateTime.now();

    await _firestore.runTransaction((tx) async {
      tx.set(jarRef, {
        'name': name,
        'emoji': emoji,
        'targetAmount': targetAmount,
        'currentAmount': initialDeposit,
        'deadline': deadline,
        'createdAt': now,
        'coupleId': coupleId,
        if (bankCode != null && bankCode.isNotEmpty) 'bankCode': bankCode,
        if (bankAccountNumber != null && bankAccountNumber.isNotEmpty)
          'bankAccountNumber': bankAccountNumber,
        if (bankAccountName != null && bankAccountName.isNotEmpty)
          'bankAccountName': bankAccountName,
      });

      if (initialDeposit > 0 && contribRef != null) {
        tx.set(contribRef, {
          'userId': '__creator__',
          'amount': initialDeposit,
          'note': 'Initial deposit',
          'source': 'manual',
          'createdAt': now,
          'coupleId': coupleId,
          'jarId': jarRef.id,
        });
      }
    });
  }

  @override
  Future<void> contribute({
    required String coupleId,
    required String jarId,
    required String userId,
    required String userName,
    required int amount,
    String? note,
    required String method,
  }) async {
    if (amount <= 0) {
      throw AuthException('Invalid amount');
    }

    final jarRef = _jarDoc(coupleId, jarId);
    final contribRef = jarRef.collection('contributions').doc();
    final now = DateTime.now();

    await _firestore.runTransaction((tx) async {
      // READS first
      final jarSnap = await tx.get(jarRef);
      if (!jarSnap.exists) {
        throw AuthException('Jar not found');
      }

      // WRITES after reads
      tx.set(contribRef, {
        'userId': userId,
        'userName': userName,
        'amount': amount,
        'note': note,
        'method': method,
        'source': method,
        'createdAt': now,
        'coupleId': coupleId,
        'jarId': jarId,
      });

      final current = (jarSnap.data()!['currentAmount'] as num?)?.toInt() ?? 0;
      tx.update(jarRef, {'currentAmount': current + amount});
    });
  }

  @override
  Future<void> deleteJar({
    required String coupleId,
    required String jarId,
  }) async {
    final jarRef = _jarDoc(coupleId, jarId);
    final contribs = await _contribsCol(coupleId, jarId).get();
    final batch = _firestore.batch();
    for (final doc in contribs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(jarRef);
    await batch.commit();
  }
}
