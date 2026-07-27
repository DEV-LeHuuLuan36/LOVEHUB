import 'package:flutter/foundation.dart';

/// Singleton schema version — bump this when the backup format changes
/// in a backwards-incompatible way so that importAllData() can detect
/// and reject files created with older versions.
const int kBackupSchemaVersion = 1;

// ─── User snapshot ────────────────────────────────────────────────────────────
@immutable
class UserBackup {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;

  const UserBackup({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
  });

  factory UserBackup.fromJson(Map<String, dynamic> json) {
    return UserBackup(
      uid: json['uid'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserBackup &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          displayName == other.displayName &&
          email == other.email &&
          photoUrl == other.photoUrl;

  @override
  int get hashCode =>
      uid.hashCode ^ displayName.hashCode ^ email.hashCode ^ photoUrl.hashCode;
}

// ─── Couple snapshot ───────────────────────────────────────────────────────────
@immutable
class CoupleBackup {
  final String partnerName;
  final String? partnerEmail;
  final String startDate; // yyyy-MM-dd

  const CoupleBackup({
    required this.partnerName,
    this.partnerEmail,
    required this.startDate,
  });

  factory CoupleBackup.fromJson(Map<String, dynamic> json) {
    return CoupleBackup(
      partnerName: json['partnerName'] as String? ?? '',
      partnerEmail: json['partnerEmail'] as String?,
      startDate: json['startDate'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'partnerName': partnerName,
        if (partnerEmail != null) 'partnerEmail': partnerEmail,
        'startDate': startDate,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoupleBackup &&
          runtimeType == other.runtimeType &&
          partnerName == other.partnerName &&
          partnerEmail == other.partnerEmail &&
          startDate == other.startDate;

  @override
  int get hashCode =>
      partnerName.hashCode ^ partnerEmail.hashCode ^ startDate.hashCode;
}

// ─── Streak snapshot ──────────────────────────────────────────────────────────
@immutable
class StreakBackup {
  final int currentStreak;
  final int longestStreak;
  final int recoveryTokens;
  final String lastCheckin; // yyyy-MM-dd or ''
  final int lastTokenStreak;

  const StreakBackup({
    required this.currentStreak,
    required this.longestStreak,
    required this.recoveryTokens,
    required this.lastCheckin,
    required this.lastTokenStreak,
  });

  factory StreakBackup.fromJson(Map<String, dynamic> json) {
    return StreakBackup(
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      recoveryTokens: json['recoveryTokens'] as int? ?? 0,
      lastCheckin: json['lastCheckin'] as String? ?? '',
      lastTokenStreak: json['lastTokenStreak'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'recoveryTokens': recoveryTokens,
        'lastCheckin': lastCheckin,
        'lastTokenStreak': lastTokenStreak,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakBackup &&
          runtimeType == other.runtimeType &&
          currentStreak == other.currentStreak &&
          longestStreak == other.longestStreak &&
          recoveryTokens == other.recoveryTokens &&
          lastCheckin == other.lastCheckin &&
          lastTokenStreak == other.lastTokenStreak;

  @override
  int get hashCode =>
      currentStreak.hashCode ^
      longestStreak.hashCode ^
      recoveryTokens.hashCode ^
      lastCheckin.hashCode ^
      lastTokenStreak.hashCode;
}

// ─── Pet snapshot ─────────────────────────────────────────────────────────────
@immutable
class PetBackup {
  final String name;
  final int level;
  final int hp;
  final int maxHp;
  final int lovePoints;
  final String? outfit;

  const PetBackup({
    required this.name,
    required this.level,
    required this.hp,
    required this.maxHp,
    required this.lovePoints,
    this.outfit,
  });

  factory PetBackup.fromJson(Map<String, dynamic> json) {
    return PetBackup(
      name: json['name'] as String? ?? '',
      level: json['level'] as int? ?? 1,
      hp: json['hp'] as int? ?? 100,
      maxHp: json['maxHp'] as int? ?? 100,
      lovePoints: json['lovePoints'] as int? ?? 0,
      outfit: json['outfit'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'level': level,
        'hp': hp,
        'maxHp': maxHp,
        'lovePoints': lovePoints,
        if (outfit != null) 'outfit': outfit,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetBackup &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          level == other.level &&
          hp == other.hp &&
          maxHp == other.maxHp &&
          lovePoints == other.lovePoints &&
          outfit == other.outfit;

  @override
  int get hashCode =>
      name.hashCode ^
      level.hashCode ^
      hp.hashCode ^
      maxHp.hashCode ^
      lovePoints.hashCode ^
      outfit.hashCode;
}

// ─── Mood entry ──────────────────────────────────────────────────────────────
@immutable
class MoodEntryBackup {
  final String date;       // yyyy-MM-dd
  final String mood;       // e.g. 'happy', 'sad'
  final String? note;
  final String emoji;

  const MoodEntryBackup({
    required this.date,
    required this.mood,
    this.note,
    required this.emoji,
  });

  factory MoodEntryBackup.fromJson(Map<String, dynamic> json) {
    return MoodEntryBackup(
      date: json['date'] as String? ?? '',
      mood: json['mood'] as String? ?? '',
      note: json['note'] as String?,
      emoji: json['emoji'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'mood': mood,
        if (note != null) 'note': note,
        'emoji': emoji,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodEntryBackup &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          mood == other.mood &&
          note == other.note &&
          emoji == other.emoji;

  @override
  int get hashCode => date.hashCode ^ mood.hashCode ^ note.hashCode ^ emoji.hashCode;
}

// ─── Memory entry ────────────────────────────────────────────────────────────
@immutable
class MemoryEntryBackup {
  final String id;
  final String title;
  final String? story;
  final String category;
  final String date;       // yyyy-MM-dd
  final List<String> imageUrls;
  final String? mood;
  final String createdAt;   // ISO 8601

  const MemoryEntryBackup({
    required this.id,
    required this.title,
    this.story,
    required this.category,
    required this.date,
    required this.imageUrls,
    this.mood,
    required this.createdAt,
  });

  factory MemoryEntryBackup.fromJson(Map<String, dynamic> json) {
    return MemoryEntryBackup(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      story: json['story'] as String?,
      category: json['category'] as String? ?? 'other',
      date: json['date'] as String? ?? '',
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      mood: json['mood'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (story != null) 'story': story,
        'category': category,
        'date': date,
        'imageUrls': imageUrls,
        if (mood != null) 'mood': mood,
        'createdAt': createdAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryEntryBackup &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          story == other.story &&
          category == other.category &&
          date == other.date &&
          _listEquals(imageUrls, other.imageUrls) &&
          mood == other.mood &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
      id, title, story, category, date, Object.hashAll(imageUrls), mood, createdAt);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ─── Saving jar entry ────────────────────────────────────────────────────────
@immutable
class SavingJarEntryBackup {
  final String id;
  final String name;
  final String emoji;
  final int currentAmount;
  final int targetAmount;
  final String? deadline; // ISO 8601 or ''

  const SavingJarEntryBackup({
    required this.id,
    required this.name,
    required this.emoji,
    required this.currentAmount,
    required this.targetAmount,
    this.deadline,
  });

  factory SavingJarEntryBackup.fromJson(Map<String, dynamic> json) {
    return SavingJarEntryBackup(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '',
      currentAmount: json['currentAmount'] as int? ?? 0,
      targetAmount: json['targetAmount'] as int? ?? 0,
      deadline: json['deadline'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'currentAmount': currentAmount,
        'targetAmount': targetAmount,
        if (deadline != null) 'deadline': deadline,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavingJarEntryBackup &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          emoji == other.emoji &&
          currentAmount == other.currentAmount &&
          targetAmount == other.targetAmount &&
          deadline == other.deadline;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      emoji.hashCode ^
      currentAmount.hashCode ^
      targetAmount.hashCode ^
      deadline.hashCode;
}

// ─── Location history entry ───────────────────────────────────────────────────
@immutable
class LocationEntryBackup {
  final double latitude;
  final double longitude;
  final String? name;

  const LocationEntryBackup({
    required this.latitude,
    required this.longitude,
    this.name,
  });

  factory LocationEntryBackup.fromJson(Map<String, dynamic> json) {
    return LocationEntryBackup(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        if (name != null) 'name': name,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationEntryBackup &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          name == other.name;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode ^ name.hashCode;
}

// ─── Top-level backup container ──────────────────────────────────────────────
@immutable
class BackupData {
  final int version;
  final String exportedAt; // ISO 8601 UTC
  final UserBackup user;
  final CoupleBackup? couple;
  final StreakBackup streak;
  final PetBackup? pet;
  final List<MoodEntryBackup> moods;
  final List<MemoryEntryBackup> memories;
  final List<SavingJarEntryBackup> savingJars;
  final List<String> milestones;
  final List<LocationEntryBackup>? locationHistory;

  const BackupData({
    required this.version,
    required this.exportedAt,
    required this.user,
    this.couple,
    required this.streak,
    this.pet,
    required this.moods,
    required this.memories,
    required this.savingJars,
    required this.milestones,
    this.locationHistory,
  });

  /// Deserialises from a JSON map produced by `toJson()`.
  factory BackupData.fromJson(Map<String, dynamic> json) {
    return BackupData(
      version: json['version'] as int? ?? 0,
      exportedAt: json['exportedAt'] as String? ?? '',
      user: json['user'] != null
          ? UserBackup.fromJson(json['user'] as Map<String, dynamic>)
          : const UserBackup(uid: '', displayName: '', email: ''),
      couple: json['couple'] != null
          ? CoupleBackup.fromJson(json['couple'] as Map<String, dynamic>)
          : null,
      streak: json['streak'] != null
          ? StreakBackup.fromJson(json['streak'] as Map<String, dynamic>)
          : const StreakBackup(
              currentStreak: 0,
              longestStreak: 0,
              recoveryTokens: 0,
              lastCheckin: '',
              lastTokenStreak: 0,
            ),
      pet: json['pet'] != null
          ? PetBackup.fromJson(json['pet'] as Map<String, dynamic>)
          : null,
      moods: (json['moods'] as List<dynamic>?)
              ?.map((e) => MoodEntryBackup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      memories: (json['memories'] as List<dynamic>?)
              ?.map((e) => MemoryEntryBackup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      savingJars: (json['savingJars'] as List<dynamic>?)
              ?.map((e) => SavingJarEntryBackup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      milestones: (json['milestones'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      locationHistory: (json['locationHistory'] as List<dynamic>?)
          ?.map((e) => LocationEntryBackup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Serialises to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'version': version,
        'exportedAt': exportedAt,
        'user': user.toJson(),
        if (couple != null) 'couple': couple!.toJson(),
        'streak': streak.toJson(),
        if (pet != null) 'pet': pet!.toJson(),
        'moods': moods.map((e) => e.toJson()).toList(),
        'memories': memories.map((e) => e.toJson()).toList(),
        'savingJars': savingJars.map((e) => e.toJson()).toList(),
        'milestones': milestones,
        if (locationHistory != null)
          'locationHistory': locationHistory!.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupData &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          exportedAt == other.exportedAt &&
          user == other.user &&
          couple == other.couple &&
          streak == other.streak &&
          pet == other.pet &&
          _listEquals(moods, other.moods) &&
          _listEquals(memories, other.memories) &&
          _listEquals(savingJars, other.savingJars) &&
          _listEquals(milestones, other.milestones) &&
          _listEquals(locationHistory ?? [], other.locationHistory ?? []);

  @override
  int get hashCode => Object.hash(
        version,
        exportedAt,
        user,
        couple,
        streak,
        pet,
        Object.hashAll(moods),
        Object.hashAll(memories),
        Object.hashAll(savingJars),
        Object.hashAll(milestones),
        Object.hashAll(locationHistory ?? []),
      );
}
