import 'package:flutter/foundation.dart';

/// A single memory category (love, travel, food, etc.).
/// The `id` is what gets stored on the `Memory` document in Firestore and
/// the `labelKey` is the translation key used to render the human label.
@immutable
class MemoryCategory {
  const MemoryCategory({
    required this.id,
    required this.emoji,
    required this.labelKey,
  });

  /// Stable identifier persisted on Memory.category (e.g. 'love', 'travel').
  final String id;

  /// Emoji shown in the UI next to the label.
  final String emoji;

  /// easy_localization key used to localize the human-readable label.
  final String labelKey;
}

/// Single source of truth for memory categories used across diary/timeline
/// screens and the add-memory picker. Order here is the picker order.
const List<MemoryCategory> memoryCategories = [
  MemoryCategory(id: 'love', emoji: '💕', labelKey: 'memory.category.love'),
  MemoryCategory(id: 'travel', emoji: '✈️', labelKey: 'memory.category.travel'),
  MemoryCategory(id: 'food', emoji: '🍜', labelKey: 'memory.category.food'),
  MemoryCategory(id: 'date', emoji: '💑', labelKey: 'memory.category.date'),
  MemoryCategory(id: 'milestone', emoji: '⭐', labelKey: 'memory.category.milestone'),
  MemoryCategory(id: 'other', emoji: '📝', labelKey: 'memory.category.other'),
];

const String _defaultCategoryId = 'other';

/// Legacy mapping — old documents stored the category as a human string with
/// an inline emoji, e.g. "🌿 travel". Map those to the new canonical id so
/// existing memories don't render the wrong emoji/label.
const Map<String, String> _legacyCategoryAliases = {
  'travel': 'travel',
  'food': 'food',
  'movie': 'food', // closest fit for old "🎬 movie" entries
  'special': 'milestone', // old "🎉 special" -> milestone
  'romantic': 'love',
  'birthday': 'milestone',
  'milestone': 'milestone',
  'love': 'love',
  'date': 'date',
  'other': 'other',
  '🌿 travel': 'travel',
  '🍜 food': 'food',
  '🎬 movie': 'food',
  '🎉 special': 'milestone',
  '🎉 Special': 'milestone',
  '💕 romantic': 'love',
  '🎂 birthday': 'milestone',
  '⭐ milestone': 'milestone',
};

MemoryCategory _categoryById(String? id) {
  for (final c in memoryCategories) {
    if (c.id == id) return c;
  }
  // Try legacy aliases (e.g. "🌿 travel" -> travel)
  final alias = _legacyCategoryAliases[id];
  if (alias != null) {
    for (final c in memoryCategories) {
      if (c.id == alias) return c;
    }
  }
  // Fall back to "other"
  for (final c in memoryCategories) {
    if (c.id == _defaultCategoryId) return c;
  }
  return memoryCategories.first;
}

@immutable
class Memory {
  final String id;
  final String coupleId;
  final String title;
  final String? story;
  final String category; // stored as a MemoryCategory.id (e.g. 'travel')
  final DateTime date;
  final List<String> photoUrls;
  final String? mood;
  final String authorUid;
  final DateTime createdAt;

  const Memory({
    required this.id,
    required this.coupleId,
    required this.title,
    this.story,
    required this.category,
    required this.date,
    required this.photoUrls,
    this.mood,
    required this.authorUid,
    required this.createdAt,
  });

  Memory copyWith({
    String? id,
    String? coupleId,
    String? title,
    String? story,
    String? category,
    DateTime? date,
    List<String>? photoUrls,
    String? mood,
    String? authorUid,
    DateTime? createdAt,
  }) {
    return Memory(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      title: title ?? this.title,
      story: story ?? this.story,
      category: category ?? this.category,
      date: date ?? this.date,
      photoUrls: photoUrls ?? this.photoUrls,
      mood: mood ?? this.mood,
      authorUid: authorUid ?? this.authorUid,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get monthYear {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }

  String get formattedDate {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Resolved category for this memory. Falls back to "other" if the stored
  /// value doesn't match any known id (e.g. legacy "🎉 Special").
  MemoryCategory get memoryCategory => _categoryById(category);

  /// Emoji for this memory's category (e.g. "💕" for love).
  /// Falls back to the default category's emoji for unknown values.
  String get categoryEmoji => memoryCategory.emoji;

  /// Resolved category id (e.g. "love"). Unknown stored values map to "other".
  String get resolvedCategoryId => memoryCategory.id;

  /// Localized label key for this memory's category (e.g.
  /// `"memory.category.love"`). The caller must call `.tr()` on it from a
  /// `BuildContext` so the ambient locale is picked up. The label keys live
  /// in `assets/translations/{vi,en}.json` under `memory.category.*`.
  String get categoryLabel => memoryCategory.labelKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Memory && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
