import 'package:flutter/foundation.dart';

enum PetType {
  cat,
  habitspet,
  muza;

  String get emoji {
    switch (this) {
      case PetType.cat: return '🐱';
      case PetType.habitspet: return '😺';
      case PetType.muza: return '🐈';
    }
  }

  String get displayName {
    switch (this) {
      case PetType.cat: return 'Cat';
      case PetType.habitspet: return 'Habit Cat';
      case PetType.muza: return 'Muza';
    }
  }

  String get assetPath {
    switch (this) {
      case PetType.cat: return 'assets/rive/cat.riv';
      case PetType.habitspet: return 'assets/rive/habitspet.riv';
      case PetType.muza: return 'assets/rive/muza-your-cat-companion.riv';
    }
  }

  String get artboardName {
    switch (this) {
      case PetType.cat: return 'Artboard';
      case PetType.habitspet: return 'habits-cat';
      case PetType.muza: return 'Artboard';
    }
  }

  String get stateMachineName => 'State Machine 1';

  int get unlockLevel {
    switch (this) {
      case PetType.cat: return 1;
      case PetType.habitspet: return 5;
      case PetType.muza: return 10;
    }
  }

  bool get isInteractive {
    switch (this) {
      case PetType.cat: return true;
      case PetType.habitspet: return false;
      case PetType.muza: return true;
    }
  }

  /// Translation key for the small caption shown under the pet.
  String get patHintKey {
    switch (this) {
      case PetType.cat:
        return 'pet.tapToPatHint';
      case PetType.habitspet:
        return 'pet.tapToPlayHint';
      case PetType.muza:
        return 'pet.tapToPatHint';
    }
  }

  /// Legacy plain-text hint. Kept as a fallback only — the UI now
  /// displays [patHintKey] via easy_localization.
  String get patHint {
    switch (this) {
      case PetType.cat:
        return 'Tap to pet \u00b7 Hold to hear purr';
      case PetType.habitspet:
        return 'Tap to play';
      case PetType.muza:
        return 'Tap to pet \u00b7 Hold to hear purr';
    }
  }
}

@immutable
class PetEntity {
  final String coupleId;
  final PetType type;
  final int lovePoints;
  final int hp;
  final int food;
  final String? lastHpDecayDate;
  final String? patDate;
  final int patCountToday;
  final String? lastFeedDate;

  const PetEntity({
    required this.coupleId,
    this.type = PetType.cat,
    this.lovePoints = 0,
    this.hp = 100,
    this.food = 0,
    this.lastHpDecayDate,
    this.patDate,
    this.patCountToday = 0,
    this.lastFeedDate,
  });

  static int cumulativeLp(int level) => 100 * (level - 1) * level ~/ 2;

  static int computeLevel(int lp) {
    for (int l = 10; l >= 1; l--) {
      if (lp >= cumulativeLp(l)) return l;
    }
    return 1;
  }

  static const int maxHp = 100;
  static const int maxLevel = 10;
  static const int maxPatPerDay = 5;
  static const int feedHpGain = 20;
  static const int feedLpGain = 5;
  static const int patLpGain = 2;

  int get level => computeLevel(lovePoints);

  int get expIntoLevel => lovePoints - cumulativeLp(level);

  int get expForThisLevel => level >= 10 ? 0 : level * 100;

  double get levelProgress =>
      level >= 10 ? 1.0 : (expForThisLevel > 0 ? expIntoLevel / expForThisLevel : 0.0);

  bool get canFeed => food >= 1 && hp < maxHp;

  bool get canPatToday => patCountToday < maxPatPerDay;

  List<PetType> get unlockedPetTypes {
    final unlocked = <PetType>[PetType.cat];
    if (level >= 5) unlocked.add(PetType.habitspet);
    if (level >= 10) unlocked.add(PetType.muza);
    return unlocked;
  }

  bool isTypeUnlocked(PetType t) => unlockedPetTypes.contains(t);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetEntity &&
          runtimeType == other.runtimeType &&
          coupleId == other.coupleId &&
          lovePoints == other.lovePoints &&
          hp == other.hp &&
          food == other.food &&
          patCountToday == other.patCountToday &&
          lastFeedDate == other.lastFeedDate;

  @override
  int get hashCode =>
      coupleId.hashCode ^
      lovePoints.hashCode ^
      hp.hashCode ^
      food.hashCode ^
      patCountToday.hashCode ^
      lastFeedDate.hashCode;
}
