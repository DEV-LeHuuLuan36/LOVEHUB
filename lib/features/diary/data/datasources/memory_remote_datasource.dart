import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../models/memory_model.dart';

abstract class MemoryRemoteDataSource {
  Stream<List<MemoryModel>> watchMemories(String coupleId);
  Future<MemoryModel> addMemory({
    required String coupleId,
    required String authorUid,
    required String title,
    String? story,
    required String category,
    required DateTime date,
    String? mood,
    required List<File> photos,
  });
  Future<void> deleteMemory({required String coupleId, required String memoryId});
}

class MemoryRemoteDataSourceImpl implements MemoryRemoteDataSource {
  MemoryRemoteDataSourceImpl({
    required FirebaseFirestore firestore,
    required CloudinaryService cloudinary,
  })  : _firestore = firestore,
        _cloudinary = cloudinary;

  final FirebaseFirestore _firestore;
  final CloudinaryService _cloudinary;

  CollectionReference<Map<String, dynamic>> _col(String coupleId) =>
      _firestore.collection('memories').doc(coupleId).collection('items');

  DocumentReference<Map<String, dynamic>> _petDoc(String coupleId) =>
      _firestore.collection('pets').doc(coupleId);

  @override
  Stream<List<MemoryModel>> watchMemories(String coupleId) {
    return _col(coupleId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MemoryModel.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  @override
  Future<MemoryModel> addMemory({
    required String coupleId,
    required String authorUid,
    required String title,
    String? story,
    required String category,
    required DateTime date,
    String? mood,
    required List<File> photos,
  }) async {
    final List<String> downloadUrls = [];

    for (int i = 0; i < photos.length; i++) {
      final url = await _cloudinary.uploadImage(photos[i]);
      downloadUrls.add(url);
    }

    final docRef = _col(coupleId).doc();
    final now = DateTime.now();

    final memory = MemoryModel(
      id: docRef.id,
      coupleId: coupleId,
      title: title,
      story: story,
      category: category,
      date: date,
      photoUrls: downloadUrls,
      mood: mood,
      authorUid: authorUid,
      createdAt: now,
    );

    await _firestore.runTransaction((tx) async {
      final petSnap = await tx.get(_petDoc(coupleId));

      tx.set(docRef, memory.toFirestore());

      if (petSnap.exists) {
        final currentLp = (petSnap.data()!['lovePoints'] as int?) ?? 0;
        tx.update(_petDoc(coupleId), {'lovePoints': currentLp + 20});
      }
    });

    return memory;
  }

  @override
  Future<void> deleteMemory({required String coupleId, required String memoryId}) async {
    await _col(coupleId).doc(memoryId).delete();
  }
}
