import '../../domain/entities/pet_entity.dart';

class PetModel extends PetEntity {
  const PetModel({
    required super.coupleId,
    super.type,
    super.lovePoints,
    super.hp,
    super.food,
    super.lastHpDecayDate,
    super.patDate,
    super.patCountToday,
    super.lastFeedDate,
  });

  factory PetModel.fromFirestore(Map<String, dynamic> data, String coupleId) {
    return PetModel(
      coupleId: coupleId,
      type: _parseType(data['type'] as String?),
      lovePoints: (data['lovePoints'] as int?) ?? 0,
      hp: (data['hp'] as int?) ?? 100,
      food: (data['food'] as int?) ?? 0,
      lastHpDecayDate: data['lastHpDecayDate'] as String?,
      patDate: data['patDate'] as String?,
      patCountToday: (data['patCountToday'] as int?) ?? 0,
      lastFeedDate: data['lastFeedDate'] as String?,
    );
  }

  static PetModel empty(String coupleId) {
    return PetModel(coupleId: coupleId);
  }

  static PetType _parseType(String? value) {
    return switch (value) {
      'cat' => PetType.cat,
      'habitspet' => PetType.habitspet,
      'muza' => PetType.muza,
      _ => PetType.cat,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'lovePoints': lovePoints,
      'hp': hp,
      'food': food,
      'lastHpDecayDate': lastHpDecayDate,
      'patDate': patDate,
      'patCountToday': patCountToday,
      'lastFeedDate': lastFeedDate,
    };
  }

  PetModel copyWith({
    String? coupleId,
    PetType? type,
    int? lovePoints,
    int? hp,
    int? food,
    String? lastHpDecayDate,
    String? patDate,
    int? patCountToday,
    String? lastFeedDate,
  }) {
    return PetModel(
      coupleId: coupleId ?? this.coupleId,
      type: type ?? this.type,
      lovePoints: lovePoints ?? this.lovePoints,
      hp: hp ?? this.hp,
      food: food ?? this.food,
      lastHpDecayDate: lastHpDecayDate ?? this.lastHpDecayDate,
      patDate: patDate ?? this.patDate,
      patCountToday: patCountToday ?? this.patCountToday,
      lastFeedDate: lastFeedDate ?? this.lastFeedDate,
    );
  }
}
