import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/pet_entity.dart';
import '../../domain/entities/pat_result.dart';
import '../models/pet_model.dart';

abstract class PetRemoteDataSource {
  Stream<PetModel> watchPet(String coupleId);
  Future<PetModel> feed(String coupleId);
  Future<PatResult> pat(String coupleId);
  Future<void> addLovePoints(String coupleId, int amount);
  Future<void> addFood(String coupleId, int amount);
  Future<void> setPetType(String coupleId, PetType type);
}

class PetRemoteDataSourceImpl implements PetRemoteDataSource {
  PetRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('pets');

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Stream<PetModel> watchPet(String coupleId) {
    return _col.doc(coupleId).snapshots().asyncMap((snap) async {
      if (!snap.exists) {
        final defaultPet = PetModel.empty(coupleId);
        await snap.reference.set(defaultPet.toFirestore());
        return defaultPet;
      }

      var pet = PetModel.fromFirestore(snap.data()!, coupleId);

      final today = _todayStr();
      if (pet.lastHpDecayDate != null && pet.lastHpDecayDate != today) {
        final lastDate = DateTime.parse(pet.lastHpDecayDate!);
        final todayDate = DateTime.now();
        final lastDateOnly = DateTime(lastDate.year, lastDate.month, lastDate.day);
        final todayOnly = DateTime(todayDate.year, todayDate.month, todayDate.day);
        final daysMissed = todayOnly.difference(lastDateOnly).inDays;

        if (daysMissed > 0 && pet.hp > 0) {
          final newHp = (pet.hp - (daysMissed * 5)).clamp(0, PetEntity.maxHp);
          await snap.reference.update({
            'hp': newHp,
            'lastHpDecayDate': today,
          });
          pet = pet.copyWith(hp: newHp, lastHpDecayDate: today);
        }
      } else if (pet.lastHpDecayDate == null) {
        await snap.reference.update({'lastHpDecayDate': today});
        pet = pet.copyWith(lastHpDecayDate: today);
      }

      return pet;
    });
  }

  @override
  Future<PetModel> feed(String coupleId) async {
    final docRef = _col.doc(coupleId);
    final today = _todayStr();

    return await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw PetException('Pet not found');

      final pet = PetModel.fromFirestore(snap.data()!, coupleId);

      if (pet.food < 1) {
        throw PetException('No food');
      }
      if (pet.hp >= PetEntity.maxHp) {
        throw PetException('HP is full');
      }

      final newHp = (pet.hp + 20).clamp(0, PetEntity.maxHp);

      tx.update(docRef, {
        'food': pet.food - 1,
        'hp': newHp,
        'lovePoints': pet.lovePoints + 5,
        'lastHpDecayDate': today,
        'lastFeedDate': today,
      });

      return pet.copyWith(
        food: pet.food - 1,
        hp: newHp,
        lovePoints: pet.lovePoints + 5,
        lastHpDecayDate: today,
        lastFeedDate: today,
      );
    });
  }

  @override
  Future<PatResult> pat(String coupleId) async {
    final docRef = _col.doc(coupleId);
    final today = _todayStr();

    return await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw PetException('Pet not found');

      final pet = PetModel.fromFirestore(snap.data()!, coupleId);

      int newPatCount = pet.patDate == today ? pet.patCountToday : 0;
      final newPatDate = pet.patDate == today ? pet.patDate! : today;

      if (newPatCount >= 5) {
        return PatResult.capped;
      }

      tx.update(docRef, {
        'patCountToday': newPatCount + 1,
        'patDate': newPatDate,
        'lovePoints': pet.lovePoints + 2,
      });

      return PatResult.awarded;
    });
  }

  @override
  Future<void> addLovePoints(String coupleId, int amount) async {
    final docRef = _col.doc(coupleId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        tx.set(docRef, {'lovePoints': amount});
        return;
      }
      final pet = PetModel.fromFirestore(snap.data()!, coupleId);
      tx.update(docRef, {'lovePoints': pet.lovePoints + amount});
    });
  }

  @override
  Future<void> addFood(String coupleId, int amount) async {
    final docRef = _col.doc(coupleId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        tx.set(docRef, {'food': amount});
        return;
      }
      final pet = PetModel.fromFirestore(snap.data()!, coupleId);
      tx.update(docRef, {'food': pet.food + amount});
    });
  }

  @override
  Future<void> setPetType(String coupleId, PetType type) async {
    final docRef = _col.doc(coupleId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        tx.set(docRef, {'type': type.name});
        return;
      }
      tx.update(docRef, {'type': type.name});
    });
  }
}
