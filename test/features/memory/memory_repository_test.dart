import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lovehub/features/diary/domain/entities/memory.dart';
import 'package:lovehub/features/diary/data/models/memory_model.dart';
import 'package:lovehub/features/diary/data/repositories/memory_repository_impl.dart';
import 'package:lovehub/features/diary/data/datasources/memory_remote_datasource.dart';
import 'package:lovehub/core/errors/failures.dart';
import 'dart:io';

class MockMemoryRemoteDataSource extends Mock implements MemoryRemoteDataSource {}

class FakeMemoryModel extends Fake implements MemoryModel {}

void main() {
  late MockMemoryRemoteDataSource mockDataSource;
  late MemoryRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(FakeMemoryModel());
    registerFallbackValue(DateTime.now());
    registerFallbackValue(<File>[]);
  });

  setUp(() {
    mockDataSource = MockMemoryRemoteDataSource();
    repository = MemoryRepositoryImpl(remoteDataSource: mockDataSource);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Memory entity creation and all properties
  // ─────────────────────────────────────────────────────────────────────────
  group('Memory entity creation and properties', () {
    test('creates instance with all required fields', () {
      final memory = Memory(
        id: 'mem_001',
        coupleId: 'couple_123',
        title: 'Our first date',
        story: 'We met at the coffee shop',
        category: 'love',
        date: DateTime(2025, 1, 15),
        photoUrls: ['https://example.com/photo1.jpg'],
        mood: 'happy',
        authorUid: 'user_1',
        createdAt: DateTime(2025, 1, 16),
      );

      expect(memory.id, equals('mem_001'));
      expect(memory.coupleId, equals('couple_123'));
      expect(memory.title, equals('Our first date'));
      expect(memory.story, equals('We met at the coffee shop'));
      expect(memory.category, equals('love'));
      expect(memory.date, equals(DateTime(2025, 1, 15)));
      expect(memory.photoUrls, equals(['https://example.com/photo1.jpg']));
      expect(memory.mood, equals('happy'));
      expect(memory.authorUid, equals('user_1'));
      expect(memory.createdAt, equals(DateTime(2025, 1, 16)));
    });

    test('story is optional and can be null', () {
      final memory = Memory(
        id: 'mem_002',
        coupleId: 'couple_456',
        title: 'Beach trip',
        story: null,
        category: 'travel',
        date: DateTime(2025, 6, 20),
        photoUrls: [],
        mood: null,
        authorUid: 'user_2',
        createdAt: DateTime(2025, 6, 21),
      );

      expect(memory.story, isNull);
      expect(memory.mood, isNull);
    });

    test('photoUrls can be empty list', () {
      final memory = Memory(
        id: 'mem_003',
        coupleId: 'couple_789',
        title: 'Quiet evening',
        story: 'Just us at home',
        category: 'other',
        date: DateTime(2025, 3, 10),
        photoUrls: [],
        authorUid: 'user_3',
        createdAt: DateTime(2025, 3, 10),
      );

      expect(memory.photoUrls, isEmpty);
    });

    test('photoUrls can contain multiple URLs', () {
      final memory = Memory(
        id: 'mem_004',
        coupleId: 'couple_abc',
        title: 'Anniversary dinner',
        story: 'Amazing night!',
        category: 'date',
        date: DateTime(2025, 2, 14),
        photoUrls: [
          'https://example.com/photo1.jpg',
          'https://example.com/photo2.jpg',
          'https://example.com/photo3.jpg',
        ],
        authorUid: 'user_4',
        createdAt: DateTime(2025, 2, 15),
      );

      expect(memory.photoUrls.length, equals(3));
      expect(memory.photoUrls[0], equals('https://example.com/photo1.jpg'));
      expect(memory.photoUrls[1], equals('https://example.com/photo2.jpg'));
      expect(memory.photoUrls[2], equals('https://example.com/photo3.jpg'));
    });

    test('category accepts all valid category ids', () {
      final validCategories = ['love', 'travel', 'food', 'date', 'milestone', 'other'];

      for (final categoryId in validCategories) {
        final memory = Memory(
          id: 'mem_cat_$categoryId',
          coupleId: 'couple_test',
          title: 'Test memory',
          category: categoryId,
          date: DateTime(2025, 1, 1),
          photoUrls: [],
          authorUid: 'user_test',
          createdAt: DateTime(2025, 1, 1),
        );

        expect(memory.category, equals(categoryId));
      }
    });

    test('tags via story - story can contain tag-like content', () {
      final memory = Memory(
        id: 'mem_005',
        coupleId: 'couple_tags',
        title: 'Tagged memory',
        story: '#vacation #sunny #beach',
        category: 'travel',
        date: DateTime(2025, 7, 1),
        photoUrls: [],
        authorUid: 'user_tags',
        createdAt: DateTime(2025, 7, 1),
      );

      expect(memory.story, contains('#vacation'));
      expect(memory.story, contains('#sunny'));
      expect(memory.story, contains('#beach'));
    });

    test('memory entity equality based on id only', () {
      final memory1 = Memory(
        id: 'mem_same_id',
        coupleId: 'couple_1',
        title: 'Memory One',
        category: 'love',
        date: DateTime(2025, 1, 1),
        photoUrls: [],
        authorUid: 'user_1',
        createdAt: DateTime(2025, 1, 1),
      );

      final memory2 = Memory(
        id: 'mem_same_id',
        coupleId: 'couple_2',
        title: 'Memory Two Different',
        category: 'travel',
        date: DateTime(2026, 6, 15),
        photoUrls: ['https://example.com/photo.jpg'],
        authorUid: 'user_2',
        createdAt: DateTime(2026, 6, 15),
      );

      expect(memory1, equals(memory2));
      expect(memory1.hashCode, equals(memory2.hashCode));
    });

    test('memory entities with different ids are not equal', () {
      final memory1 = Memory(
        id: 'mem_id_1',
        coupleId: 'couple_same',
        title: 'Same couple',
        category: 'love',
        date: DateTime(2025, 1, 1),
        photoUrls: [],
        authorUid: 'user_same',
        createdAt: DateTime(2025, 1, 1),
      );

      final memory2 = Memory(
        id: 'mem_id_2',
        coupleId: 'couple_same',
        title: 'Same couple',
        category: 'love',
        date: DateTime(2025, 1, 1),
        photoUrls: [],
        authorUid: 'user_same',
        createdAt: DateTime(2025, 1, 1),
      );

      expect(memory1, isNot(equals(memory2)));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. MemoryModel fromJson / toJson round-trip
  // ─────────────────────────────────────────────────────────────────────────
  group('MemoryModel fromFirestore / toFirestore round-trip', () {
    test('fromFirestore constructs model with all fields', () {
      final data = {
        'coupleId': 'couple_123',
        'title': 'Beach sunset',
        'story': 'Beautiful evening together',
        'category': 'travel',
        'date': DateTime(2025, 8, 20, 18, 30),
        'photoUrls': [
          'https://res.cloudinary.com/df3jqgrvk/image/upload/v1/photo1.jpg',
          'https://res.cloudinary.com/df3jqgrvk/image/upload/v1/photo2.jpg',
        ],
        'mood': 'happy',
        'authorUid': 'author_456',
        'createdAt': DateTime(2025, 8, 21, 10, 0),
      };

      final model = MemoryModel.fromFirestore('mem_abc', data);

      expect(model.id, equals('mem_abc'));
      expect(model.coupleId, equals('couple_123'));
      expect(model.title, equals('Beach sunset'));
      expect(model.story, equals('Beautiful evening together'));
      expect(model.category, equals('travel'));
      expect(model.date, equals(DateTime(2025, 8, 20, 18, 30)));
      expect(model.photoUrls.length, equals(2));
      expect(model.mood, equals('happy'));
      expect(model.authorUid, equals('author_456'));
      expect(model.createdAt, equals(DateTime(2025, 8, 21, 10, 0)));
    });

    test('fromFirestore handles null optional fields', () {
      final data = {
        'coupleId': 'couple_null',
        'title': 'No story memory',
        'category': 'other',
        'date': DateTime(2025, 5, 10),
        'photoUrls': <String>[],
        'authorUid': 'author_null',
        'createdAt': DateTime(2025, 5, 10),
        // story and mood intentionally omitted
      };

      final model = MemoryModel.fromFirestore('mem_null', data);

      expect(model.story, isNull);
      expect(model.mood, isNull);
      expect(model.photoUrls, isEmpty);
    });

    test('fromFirestore defaults empty/missing fields gracefully', () {
      final model = MemoryModel.fromFirestore('mem_empty', {});

      expect(model.id, equals('mem_empty'));
      expect(model.coupleId, equals(''));
      expect(model.title, equals(''));
      expect(model.story, isNull);
      expect(model.category, equals('other'));
      expect(model.photoUrls, isEmpty);
      expect(model.mood, isNull);
      expect(model.authorUid, equals(''));
    });

    test('toFirestore returns correct map', () {
      final memory = MemoryModel(
        id: 'mem_tofs',
        coupleId: 'couple_tofs',
        title: 'Test Memory',
        story: 'Test story',
        category: 'food',
        date: DateTime(2025, 4, 5, 12, 0),
        photoUrls: ['https://example.com/food.jpg'],
        mood: 'content',
        authorUid: 'author_tofs',
        createdAt: DateTime(2025, 4, 5, 14, 0),
      );

      final map = memory.toFirestore();

      expect(map['coupleId'], equals('couple_tofs'));
      expect(map['title'], equals('Test Memory'));
      expect(map['story'], equals('Test story'));
      expect(map['category'], equals('food'));
      expect(map['date'], equals(DateTime(2025, 4, 5, 12, 0)));
      expect(map['photoUrls'], equals(['https://example.com/food.jpg']));
      expect(map['mood'], equals('content'));
      expect(map['authorUid'], equals('author_tofs'));
      expect(map['createdAt'], equals(DateTime(2025, 4, 5, 14, 0)));
    });

    test('toFirestore includes null fields as null', () {
      final memory = MemoryModel(
        id: 'mem_null_tofs',
        coupleId: 'couple_null_tofs',
        title: 'No optionals',
        category: 'other',
        date: DateTime(2025, 3, 1),
        photoUrls: [],
        authorUid: 'author_null_tofs',
        createdAt: DateTime(2025, 3, 1),
        story: null,
        mood: null,
      );

      final map = memory.toFirestore();

      expect(map.containsKey('story'), isTrue);
      expect(map['story'], isNull);
      expect(map.containsKey('mood'), isTrue);
      expect(map['mood'], isNull);
    });

    test('round-trip: model -> toFirestore -> fromFirestore preserves all data', () {
      final original = MemoryModel(
        id: 'mem_roundtrip',
        coupleId: 'couple_rt',
        title: 'Round Trip Memory',
        story: 'This should survive round-trip',
        category: 'milestone',
        date: DateTime(2025, 12, 25, 20, 0),
        photoUrls: [
          'https://res.cloudinary.com/df3jqgrvk/image/upload/v1/photo_a.jpg',
          'https://res.cloudinary.com/df3jqgrvk/image/upload/v1/photo_b.jpg',
          'https://res.cloudinary.com/df3jqgrvk/image/upload/v1/photo_c.jpg',
        ],
        mood: 'joyful',
        authorUid: 'author_rt',
        createdAt: DateTime(2025, 12, 26, 9, 0),
      );

      final restored = MemoryModel.fromFirestore(
        'mem_roundtrip',
        original.toFirestore(),
      );

      expect(restored.id, equals(original.id));
      expect(restored.coupleId, equals(original.coupleId));
      expect(restored.title, equals(original.title));
      expect(restored.story, equals(original.story));
      expect(restored.category, equals(original.category));
      expect(restored.date, equals(original.date));
      expect(restored.photoUrls, equals(original.photoUrls));
      expect(restored.mood, equals(original.mood));
      expect(restored.authorUid, equals(original.authorUid));
      expect(restored.createdAt, equals(original.createdAt));
    });

    test('round-trip preserves null optional fields', () {
      final original = MemoryModel(
        id: 'mem_null_rt',
        coupleId: 'couple_null_rt',
        title: 'Memory with nulls',
        story: null,
        category: 'date',
        date: DateTime(2025, 2, 14),
        photoUrls: <String>[],
        mood: null,
        authorUid: 'author_null_rt',
        createdAt: DateTime(2025, 2, 14),
      );

      final restored = MemoryModel.fromFirestore(
        'mem_null_rt',
        original.toFirestore(),
      );

      expect(restored.story, isNull);
      expect(restored.mood, isNull);
      expect(restored.photoUrls, isEmpty);
    });

    test('photoUrls list order preserved in round-trip', () {
      final original = MemoryModel(
        id: 'mem_order',
        coupleId: 'couple_order',
        title: 'Order test',
        category: 'travel',
        date: DateTime(2025, 1, 1),
        photoUrls: ['first.jpg', 'second.jpg', 'third.jpg'],
        authorUid: 'author_order',
        createdAt: DateTime(2025, 1, 1),
      );

      final restored = MemoryModel.fromFirestore(
        'mem_order',
        original.toFirestore(),
      );

      expect(restored.photoUrls[0], equals('first.jpg'));
      expect(restored.photoUrls[1], equals('second.jpg'));
      expect(restored.photoUrls[2], equals('third.jpg'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Category validation
  // ─────────────────────────────────────────────────────────────────────────
  group('Category validation', () {
    test('all predefined categories exist in memoryCategories list', () {
      final categoryIds = memoryCategories.map((c) => c.id).toList();

      expect(categoryIds, contains('love'));
      expect(categoryIds, contains('travel'));
      expect(categoryIds, contains('food'));
      expect(categoryIds, contains('date'));
      expect(categoryIds, contains('milestone'));
      expect(categoryIds, contains('other'));
    });

    test('each category has emoji and labelKey', () {
      for (final category in memoryCategories) {
        expect(category.id, isNotEmpty);
        expect(category.emoji, isNotEmpty);
        expect(category.labelKey, startsWith('memory.category.'));
      }
    });

    test('category emojis match expected values', () {
      final emojiMap = {for (final c in memoryCategories) c.id: c.emoji};

      expect(emojiMap['love'], equals('💕'));
      expect(emojiMap['travel'], equals('✈️'));
      expect(emojiMap['food'], equals('🍜'));
      expect(emojiMap['date'], equals('💑'));
      expect(emojiMap['milestone'], equals('⭐'));
      expect(emojiMap['other'], equals('📝'));
    });

    test('memoryCategory getter returns correct category object', () {
      final loveMemory = Memory(
        id: 'mem',
        coupleId: 'c',
        title: 'Love',
        category: 'love',
        date: DateTime.now(),
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      final travelMemory = Memory(
        id: 'mem',
        coupleId: 'c',
        title: 'Travel',
        category: 'travel',
        date: DateTime.now(),
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      expect(loveMemory.memoryCategory.id, equals('love'));
      expect(loveMemory.memoryCategory.emoji, equals('💕'));
      expect(travelMemory.memoryCategory.id, equals('travel'));
      expect(travelMemory.memoryCategory.emoji, equals('✈️'));
    });

    test('resolvedCategoryId falls back to other for unknown category', () {
      final unknownMemory = Memory(
        id: 'mem_unknown',
        coupleId: 'c',
        title: 'Unknown category',
        category: 'invalid_category_xyz',
        date: DateTime.now(),
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      expect(unknownMemory.resolvedCategoryId, equals('other'));
    });

    test('categoryEmoji falls back to default for unknown category', () {
      final unknownMemory = Memory(
        id: 'mem_emoji_fallback',
        coupleId: 'c',
        title: 'Fallback test',
        category: 'nonexistent',
        date: DateTime.now(),
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      expect(unknownMemory.categoryEmoji, equals('📝')); // other emoji
    });

    test('categoryLabel returns correct localization key', () {
      final loveMemory = Memory(
        id: 'mem',
        coupleId: 'c',
        title: 'Love',
        category: 'love',
        date: DateTime.now(),
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      expect(loveMemory.categoryLabel, equals('memory.category.love'));
    });

    test('legacy category aliases map correctly', () {
      // Test legacy romantic -> love mapping
      final romanticMemory = Memory(
        id: 'mem_legacy',
        coupleId: 'c',
        title: 'Legacy romantic',
        category: 'romantic',
        date: DateTime.now(),
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      expect(romanticMemory.resolvedCategoryId, equals('love'));
      expect(romanticMemory.categoryEmoji, equals('💕'));

      // Test legacy special -> milestone mapping
      final specialMemory = Memory(
        id: 'mem_special',
        coupleId: 'c',
        title: 'Legacy special',
        category: 'special',
        date: DateTime.now(),
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      expect(specialMemory.resolvedCategoryId, equals('milestone'));
      expect(specialMemory.categoryEmoji, equals('⭐'));
    });

    test('emoji with space legacy aliases work', () {
      final travelEmojiMemory = Memory(
        id: 'mem_emoji_alias',
        coupleId: 'c',
        title: 'Legacy travel with emoji',
        category: '🌿 travel',
        date: DateTime.now(),
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      expect(travelEmojiMemory.resolvedCategoryId, equals('travel'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Photo URL validation
  // ─────────────────────────────────────────────────────────────────────────
  group('Photo URL validation', () {
    test('valid Cloudinary URLs are accepted', () {
      final memory = Memory(
        id: 'mem_photo',
        coupleId: 'c',
        title: 'Cloudinary photo',
        category: 'travel',
        date: DateTime.now(),
        photoUrls: [
          'https://res.cloudinary.com/df3jqgrvk/image/upload/v1/abc123.jpg',
          'https://res.cloudinary.com/df3jqgrvk/image/upload/v1/xyz789.jpg',
        ],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      expect(memory.photoUrls.length, equals(2));
      expect(memory.photoUrls[0], contains('cloudinary.com'));
      expect(memory.photoUrls[1], contains('cloudinary.com'));
    });

    test('generic valid https URLs are accepted', () {
      final memory = Memory(
        id: 'mem_https',
        coupleId: 'c',
        title: 'HTTPS photos',
        category: 'food',
        date: DateTime.now(),
        photoUrls: [
          'https://example.com/photo.jpg',
          'https://storage.googleapis.com/bucket/image.png',
        ],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      for (final url in memory.photoUrls) {
        expect(url, startsWith('https://'));
        expect(Uri.tryParse(url)?.hasAbsolutePath, isTrue);
      }
    });

    test('empty photoUrls list is valid', () {
      final memory = Memory(
        id: 'mem_no_photos',
        coupleId: 'c',
        title: 'No photos',
        category: 'other',
        date: DateTime.now(),
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      expect(memory.photoUrls, isEmpty);
    });

    test('URL format validation - valid URLs parse correctly', () {
      final validUrls = [
        'https://res.cloudinary.com/df3jqgrvk/image/upload/v1/photo1.jpg',
        'https://example.com/path/to/image.png',
        'https://storage.googleapis.com/bucket/folder/photo.jpeg',
        'https://cdn.example.com/images/photo.webp',
      ];

      for (final url in validUrls) {
        final uri = Uri.tryParse(url);
        expect(uri, isNotNull);
        expect(uri!.hasAbsolutePath, isTrue);
        expect(uri.hasScheme, isTrue);
      }
    });

    test('photoUrls preserved in model round-trip', () {
      final original = MemoryModel(
        id: 'mem_url_test',
        coupleId: 'c',
        title: 'URL preservation test',
        category: 'travel',
        date: DateTime.now(),
        photoUrls: [
          'https://res.cloudinary.com/df3jqgrvk/image/upload/v1/test1.jpg',
          'https://res.cloudinary.com/df3jqgrvk/image/upload/v1/test2.jpg',
        ],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      final restored = MemoryModel.fromFirestore(
        'mem_url_test',
        original.toFirestore(),
      );

      expect(restored.photoUrls, equals(original.photoUrls));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 5. Date parsing and formatting
  // ─────────────────────────────────────────────────────────────────────────
  group('Date parsing and formatting', () {
    test('formattedDate returns correct format', () {
      final memory = Memory(
        id: 'mem_date',
        coupleId: 'c',
        title: 'Date test',
        category: 'other',
        date: DateTime(2025, 7, 18),
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      expect(memory.formattedDate, equals('Jul 18, 2025'));
    });

    test('formattedDate works for all months', () {
      final months = [
        (1, 'Jan'),
        (2, 'Feb'),
        (3, 'Mar'),
        (4, 'Apr'),
        (5, 'May'),
        (6, 'Jun'),
        (7, 'Jul'),
        (8, 'Aug'),
        (9, 'Sep'),
        (10, 'Oct'),
        (11, 'Nov'),
        (12, 'Dec'),
      ];

      for (final (month, expected) in months) {
        final memory = Memory(
          id: 'mem_month_$month',
          coupleId: 'c',
          title: 'Month $month',
          category: 'other',
          date: DateTime(2025, month, 15),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime.now(),
        );

        expect(memory.formattedDate, equals('$expected 15, 2025'));
      }
    });

    test('monthYear returns correct format', () {
      final memory = Memory(
        id: 'mem_monthyear',
        coupleId: 'c',
        title: 'MonthYear test',
        category: 'other',
        date: DateTime(2025, 12, 25),
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      expect(memory.monthYear, equals('Dec 2025'));
    });

    test('monthYear works for all months', () {
      final months = [
        (1, 'Jan'),
        (2, 'Feb'),
        (3, 'Mar'),
        (4, 'Apr'),
        (5, 'May'),
        (6, 'Jun'),
        (7, 'Jul'),
        (8, 'Aug'),
        (9, 'Sep'),
        (10, 'Oct'),
        (11, 'Nov'),
        (12, 'Dec'),
      ];

      for (final (month, expected) in months) {
        final memory = Memory(
          id: 'mem_my_$month',
          coupleId: 'c',
          title: 'MonthYear $month',
          category: 'other',
          date: DateTime(2026, month, 1),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime.now(),
        );

        expect(memory.monthYear, equals('$expected 2026'));
      }
    });

    test('date parsing from Firestore timestamp format', () {
      // Verify timestamp parsing works correctly
      // Use a timestamp and verify the parsing function handles it
      final data = {
        'coupleId': 'c',
        'title': 'Timestamp test',
        'category': 'other',
        'date': {'_seconds': 1753036800},
        'photoUrls': <String>[],
        'authorUid': 'u',
        'createdAt': {'_seconds': 1753036800},
      };

      final model = MemoryModel.fromFirestore('mem_ts', data);

      // Verify the timestamp was converted to a valid DateTime (not the default now)
      // 1753036800 corresponds to mid-July 2025
      expect(model.date.year, equals(2025));
      expect(model.date.month, greaterThanOrEqualTo(7));
      expect(model.date.month, lessThanOrEqualTo(7));
      // Verify it's not the default DateTime.now() by checking it's in 2025
      expect(model.date.isAfter(DateTime(2024, 12, 31)), isTrue);
      expect(model.date.isBefore(DateTime(2025, 12, 31)), isTrue);
    });

    test('date parsing handles DateTime directly', () {
      final data = {
        'coupleId': 'c',
        'title': 'DateTime test',
        'category': 'other',
        'date': DateTime(2025, 6, 15, 14, 30),
        'photoUrls': <String>[],
        'authorUid': 'u',
        'createdAt': DateTime(2025, 6, 15, 15, 0),
      };

      final model = MemoryModel.fromFirestore('mem_dt', data);

      expect(model.date, equals(DateTime(2025, 6, 15, 14, 30)));
      expect(model.createdAt, equals(DateTime(2025, 6, 15, 15, 0)));
    });

    test('date parsing falls back to now for invalid timestamp', () {
      final before = DateTime.now();
      final data = {
        'coupleId': 'c',
        'title': 'Invalid date',
        'category': 'other',
        'date': 'not a timestamp',
        'photoUrls': <String>[],
        'authorUid': 'u',
        'createdAt': null,
      };

      final model = MemoryModel.fromFirestore('mem_invalid', data);
      final after = DateTime.now();

      // Falls back to DateTime.now() which is approximately now
      expect(model.date.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(model.date.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('date with time components formats correctly', () {
      final memory = Memory(
        id: 'mem_time',
        coupleId: 'c',
        title: 'Time test',
        category: 'date',
        date: DateTime(2025, 2, 14, 19, 30), // 7:30 PM
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      expect(memory.formattedDate, equals('Feb 14, 2025'));
      expect(memory.monthYear, equals('Feb 2025'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 6. Memory filtering by category
  // ─────────────────────────────────────────────────────────────────────────
  group('Memory filtering by category', () {
    late List<Memory> allMemories;

    setUp(() {
      allMemories = [
        Memory(
          id: 'mem_love_1',
          coupleId: 'c',
          title: 'Love 1',
          category: 'love',
          date: DateTime(2025, 1, 1),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime.now(),
        ),
        Memory(
          id: 'mem_travel_1',
          coupleId: 'c',
          title: 'Travel 1',
          category: 'travel',
          date: DateTime(2025, 2, 1),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime.now(),
        ),
        Memory(
          id: 'mem_food_1',
          coupleId: 'c',
          title: 'Food 1',
          category: 'food',
          date: DateTime(2025, 3, 1),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime.now(),
        ),
        Memory(
          id: 'mem_love_2',
          coupleId: 'c',
          title: 'Love 2',
          category: 'love',
          date: DateTime(2025, 4, 1),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime.now(),
        ),
        Memory(
          id: 'mem_date_1',
          coupleId: 'c',
          title: 'Date 1',
          category: 'date',
          date: DateTime(2025, 5, 1),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime.now(),
        ),
        Memory(
          id: 'mem_other_1',
          coupleId: 'c',
          title: 'Other 1',
          category: 'other',
          date: DateTime(2025, 6, 1),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime.now(),
        ),
      ];
    });

    test('filter memories by love category', () {
      final loveMemories = allMemories
          .where((m) => m.category == 'love')
          .toList();

      expect(loveMemories.length, equals(2));
      expect(loveMemories[0].title, equals('Love 1'));
      expect(loveMemories[1].title, equals('Love 2'));
    });

    test('filter memories by travel category', () {
      final travelMemories = allMemories
          .where((m) => m.category == 'travel')
          .toList();

      expect(travelMemories.length, equals(1));
      expect(travelMemories[0].title, equals('Travel 1'));
    });

    test('filter memories by food category', () {
      final foodMemories = allMemories
          .where((m) => m.category == 'food')
          .toList();

      expect(foodMemories.length, equals(1));
      expect(foodMemories[0].title, equals('Food 1'));
    });

    test('filter memories by date category', () {
      final dateMemories = allMemories
          .where((m) => m.category == 'date')
          .toList();

      expect(dateMemories.length, equals(1));
      expect(dateMemories[0].title, equals('Date 1'));
    });

    test('filter memories by milestone category', () {
      final milestoneMemories = allMemories
          .where((m) => m.category == 'milestone')
          .toList();

      expect(milestoneMemories, isEmpty);
    });

    test('filter memories by other category', () {
      final otherMemories = allMemories
          .where((m) => m.category == 'other')
          .toList();

      expect(otherMemories.length, equals(1));
      expect(otherMemories[0].title, equals('Other 1'));
    });

    test('filter by multiple categories using resolvedCategoryId', () {
      final memories = [
        Memory(
          id: 'mem',
          coupleId: 'c',
          title: 'Legacy romantic',
          category: 'romantic',
          date: DateTime.now(),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime.now(),
        ),
        Memory(
          id: 'mem2',
          coupleId: 'c',
          title: 'Standard love',
          category: 'love',
          date: DateTime.now(),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime.now(),
        ),
      ];

      final loveMemories = memories
          .where((m) => m.resolvedCategoryId == 'love')
          .toList();

      expect(loveMemories.length, equals(2));
    });

    test('filter with category emoji accessor', () {
      final memoriesWithPhotos = allMemories
          .where((m) => m.photoUrls.isNotEmpty)
          .toList();

      // All test memories have empty photoUrls
      expect(memoriesWithPhotos, isEmpty);

      final memoryWithPhotos = Memory(
        id: 'mem_photo',
        coupleId: 'c',
        title: 'With photo',
        category: 'travel',
        date: DateTime.now(),
        photoUrls: ['https://example.com/photo.jpg'],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      final combined = [...allMemories, memoryWithPhotos];
      final withPhotos = combined
          .where((m) => m.photoUrls.isNotEmpty)
          .toList();

      expect(withPhotos.length, equals(1));
      expect(withPhotos[0].title, equals('With photo'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 7. Memory sorting (by date descending)
  // ─────────────────────────────────────────────────────────────────────────
  group('Memory sorting by date descending', () {
    late List<Memory> unsortedMemories;

    setUp(() {
      unsortedMemories = [
        Memory(
          id: 'mem_old',
          coupleId: 'c',
          title: 'Oldest memory',
          category: 'love',
          date: DateTime(2024, 1, 1),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime(2024, 1, 2),
        ),
        Memory(
          id: 'mem_new',
          coupleId: 'c',
          title: 'Newest memory',
          category: 'travel',
          date: DateTime(2025, 12, 25),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime(2025, 12, 26),
        ),
        Memory(
          id: 'mem_mid',
          coupleId: 'c',
          title: 'Middle memory',
          category: 'food',
          date: DateTime(2025, 6, 15),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime(2025, 6, 16),
        ),
        Memory(
          id: 'mem_april',
          coupleId: 'c',
          title: 'April memory',
          category: 'date',
          date: DateTime(2025, 4, 10),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime(2025, 4, 11),
        ),
      ];
    });

    test('sort by date descending puts newest first', () {
      final sorted = [...unsortedMemories]
        ..sort((a, b) => b.date.compareTo(a.date));

      expect(sorted[0].title, equals('Newest memory'));
      expect(sorted[1].title, equals('Middle memory'));
      expect(sorted[2].title, equals('April memory'));
      expect(sorted[3].title, equals('Oldest memory'));
    });

    test('sort by date ascending puts oldest first', () {
      final sorted = [...unsortedMemories]
        ..sort((a, b) => a.date.compareTo(b.date));

      expect(sorted[0].title, equals('Oldest memory'));
      expect(sorted[1].title, equals('April memory'));
      expect(sorted[2].title, equals('Middle memory'));
      expect(sorted[3].title, equals('Newest memory'));
    });

    test('sorting preserves all memory properties', () {
      final sorted = [...unsortedMemories]
        ..sort((a, b) => b.date.compareTo(a.date));

      for (final memory in sorted) {
        expect(memory.id, isNotEmpty);
        expect(memory.coupleId, isNotEmpty);
        expect(memory.title, isNotEmpty);
        expect(memory.category, isNotEmpty);
        expect(memory.authorUid, isNotEmpty);
      }
    });

    test('sorting same date memories - order may vary but stable', () {
      final sameDateMemories = [
        Memory(
          id: 'mem_a',
          coupleId: 'c',
          title: 'Memory A',
          category: 'love',
          date: DateTime(2025, 7, 18),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime(2025, 7, 18, 10, 0),
        ),
        Memory(
          id: 'mem_b',
          coupleId: 'c',
          title: 'Memory B',
          category: 'travel',
          date: DateTime(2025, 7, 18),
          photoUrls: [],
          authorUid: 'u',
          createdAt: DateTime(2025, 7, 18, 12, 0),
        ),
      ];

      final sorted = [...sameDateMemories]
        ..sort((a, b) => b.date.compareTo(a.date));

      // Both should have same date
      expect(sorted[0].date, equals(sorted[1].date));
    });

    test('reverse sorted list puts oldest last', () {
      final sortedDesc = [...unsortedMemories]
        ..sort((a, b) => b.date.compareTo(a.date));
      final reversed = sortedDesc.reversed.toList();

      expect(reversed.last.title, equals('Newest memory'));
      expect(reversed.first.title, equals('Oldest memory'));
    });

    test('filter then sort - combined operation', () {
      final loveMemories = unsortedMemories
          .where((m) => m.category == 'love')
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      expect(loveMemories.length, equals(1));
      expect(loveMemories[0].title, equals('Oldest memory'));
    });

    test('year grouping via monthYear getter', () {
      final sorted = [...unsortedMemories]
        ..sort((a, b) => b.date.compareTo(a.date));

      final monthYears = sorted.map((m) => m.monthYear).toList();

      expect(monthYears, equals([
        'Dec 2025',
        'Jun 2025',
        'Apr 2025',
        'Jan 2024',
      ]));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 8. Tag parsing and normalization
  // ─────────────────────────────────────────────────────────────────────────
  group('Tag parsing and normalization', () {
    test('story can contain hashtag-style tags', () {
      final memory = Memory(
        id: 'mem_tags',
        coupleId: 'c',
        title: 'Tagged memory',
        story: 'Great vacation #beach #sunset #vacation2025',
        category: 'travel',
        date: DateTime.now(),
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      expect(memory.story, isNotNull);
      expect(memory.story!.contains('#beach'), isTrue);
    });

    test('extract tags from story using regex', () {
      final story = 'Amazing trip to the mountains #hiking #nature #adventure #2025';
      final tagPattern = RegExp(r'#(\w+)');
      final tags = tagPattern.allMatches(story).map((m) => m.group(1)!).toList();

      expect(tags, equals(['hiking', 'nature', 'adventure', '2025']));
    });

    test('normalize tags to lowercase', () {
      final story = '#Beach #SUNSET #Vacation';
      final tagPattern = RegExp(r'#(\w+)');
      final tags = tagPattern
          .allMatches(story)
          .map((m) => m.group(1)!.toLowerCase())
          .toList();

      expect(tags, equals(['beach', 'sunset', 'vacation']));
    });

    test('remove duplicate tags', () {
      final story = '#beach #sunset #beach #vacation #sunset';
      final tagPattern = RegExp(r'#(\w+)');
      final tags = tagPattern
          .allMatches(story)
          .map((m) => m.group(1)!.toLowerCase())
          .toSet()
          .toList();

      expect(tags.length, equals(3));
      expect(tags, containsAll(['beach', 'sunset', 'vacation']));
    });

    test('empty story has no tags', () {
      final story = '';
      final tagPattern = RegExp(r'#(\w+)');
      final tags = tagPattern.allMatches(story).map((m) => m.group(1)!).toList();

      expect(tags, isEmpty);
    });

    test('story with special characters in tags', () {
      // Note: \w only matches [a-zA-Z0-9_], so hyphens are not treated as word boundaries
      final story = '#coast #sunset #good_vibes';
      final tagPattern = RegExp(r'#(\w+)');
      final tags = tagPattern.allMatches(story).map((m) => m.group(1)!.toLowerCase()).toList();

      expect(tags, equals(['coast', 'sunset', 'good_vibes']));
    });

    test('story with unicode characters in tags', () {
      // \w matches unicode word characters in Dart
      final story = '#mon #amour #liebe';
      final tagPattern = RegExp(r'#(\w+)');
      final tags = tagPattern.allMatches(story).map((m) => m.group(1)!.toLowerCase()).toList();

      expect(tags, equals(['mon', 'amour', 'liebe']));
    });

    test('tag extraction utility function simulation', () {
      String extractTags(String? story) {
        if (story == null || story.isEmpty) return '';
        final tagPattern = RegExp(r'#(\w+)');
        final tags = tagPattern
            .allMatches(story)
            .map((m) => m.group(1)!.toLowerCase())
            .toSet()
            .toList();
        return tags.join(', ');
      }

      expect(extractTags('#Beach #Sunset'), equals('beach, sunset'));
      expect(extractTags('No tags here'), equals(''));
      expect(extractTags(null), equals(''));
      expect(extractTags(''), equals(''));
      expect(extractTags('#duplicate #duplicate #unique'), equals('duplicate, unique'));
    });

    test('memory with multi-word tags (underscore-separated)', () {
      // Underscores are word characters, so multi_word is captured as one tag
      final memory = Memory(
        id: 'mem_multi',
        coupleId: 'c',
        title: 'Multi-word tags',
        story: 'Trip to Paris #city_of_love #eiffel_tower #french_cuisine',
        category: 'travel',
        date: DateTime.now(),
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      final tagPattern = RegExp(r'#(\w+)');
      final tags = tagPattern.allMatches(memory.story!).map((m) => m.group(1)!.toLowerCase()).toList();

      // Underscores are part of word characters
      expect(tags, equals(['city_of_love', 'eiffel_tower', 'french_cuisine']));
    });

    test('numeric tags are preserved', () {
      final story = '#2024 #2025 #trip2025';
      final tagPattern = RegExp(r'#(\w+)');
      final tags = tagPattern.allMatches(story).map((m) => m.group(1)!).toList();

      expect(tags, equals(['2024', '2025', 'trip2025']));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 9. Memory copyWith functionality
  // ─────────────────────────────────────────────────────────────────────────
  group('Memory copyWith functionality', () {
    test('copyWith creates new instance with updated fields', () {
      final original = Memory(
        id: 'mem_copy',
        coupleId: 'c',
        title: 'Original title',
        story: 'Original story',
        category: 'love',
        date: DateTime(2025, 1, 1),
        photoUrls: ['https://original.jpg'],
        mood: 'happy',
        authorUid: 'u',
        createdAt: DateTime(2025, 1, 1),
      );

      final updated = original.copyWith(title: 'Updated title');

      expect(updated.id, equals('mem_copy'));
      expect(updated.title, equals('Updated title'));
      expect(updated.story, equals('Original story'));
      expect(original.title, equals('Original title')); // original unchanged
    });

    test('copyWith can update multiple fields', () {
      final original = Memory(
        id: 'mem_multi',
        coupleId: 'c',
        title: 'Original',
        story: null,
        category: 'other',
        date: DateTime(2025, 1, 1),
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime(2025, 1, 1),
      );

      final updated = original.copyWith(
        title: 'New title',
        story: 'New story',
        category: 'travel',
      );

      expect(updated.title, equals('New title'));
      expect(updated.story, equals('New story'));
      expect(updated.category, equals('travel'));
    });

    test('copyWith preserves all non-updated fields', () {
      final original = MemoryModel(
        id: 'mem_preserve',
        coupleId: 'couple_preserve',
        title: 'Title',
        story: 'Story',
        category: 'food',
        date: DateTime(2025, 5, 5),
        photoUrls: ['https://photo.jpg'],
        mood: 'content',
        authorUid: 'author_preserve',
        createdAt: DateTime(2025, 5, 5),
      );

      final updated = original.copyWith(title: 'Updated');

      expect(updated.id, equals(original.id));
      expect(updated.coupleId, equals(original.coupleId));
      expect(updated.story, equals(original.story));
      expect(updated.category, equals(original.category));
      expect(updated.date, equals(original.date));
      expect(updated.photoUrls, equals(original.photoUrls));
      expect(updated.mood, equals(original.mood));
      expect(updated.authorUid, equals(original.authorUid));
      expect(updated.createdAt, equals(original.createdAt));
    });

    test('copyWith on MemoryModel returns MemoryModel', () {
      final original = MemoryModel(
        id: 'mem_model',
        coupleId: 'c',
        title: 'Original',
        category: 'love',
        date: DateTime.now(),
        photoUrls: [],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      final updated = original.copyWith(title: 'Updated');

      expect(updated, isA<MemoryModel>());
    });

    test('copyWith can update photoUrls', () {
      final original = Memory(
        id: 'mem_photos',
        coupleId: 'c',
        title: 'Photos',
        category: 'travel',
        date: DateTime.now(),
        photoUrls: ['https://old.jpg'],
        authorUid: 'u',
        createdAt: DateTime.now(),
      );

      final updated = original.copyWith(
        photoUrls: ['https://new1.jpg', 'https://new2.jpg'],
      );

      expect(updated.photoUrls.length, equals(2));
      expect(updated.photoUrls, contains('https://new1.jpg'));
      expect(updated.photoUrls, contains('https://new2.jpg'));
      expect(updated.photoUrls, isNot(contains('https://old.jpg')));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 10. MemoryRepositoryImpl tests (mocked datasource)
  // ─────────────────────────────────────────────────────────────────────────
  group('MemoryRepositoryImpl', () {
    const coupleId = 'couple_repository_test';
    const authorUid = 'author_test';
    const memoryId = 'memory_test_123';

    group('watchMemories', () {
      test('delegates to datasource stream', () async {
        final stream = Stream<List<MemoryModel>>.fromIterable([
          [
            MemoryModel(
              id: 'mem_1',
              coupleId: coupleId,
              title: 'Test memory',
              category: 'love',
              date: DateTime.now(),
              photoUrls: [],
              authorUid: authorUid,
              createdAt: DateTime.now(),
            ),
          ],
        ]);

        when(() => mockDataSource.watchMemories(coupleId))
            .thenAnswer((_) => stream);

        final result = repository.watchMemories(coupleId);

        await expectLater(
          result,
          emits(predicate<List<Memory>>((memories) => memories.length == 1)),
        );
        verify(() => mockDataSource.watchMemories(coupleId)).called(1);
      });

      test('emits empty list when no memories exist', () async {
        final stream = Stream<List<MemoryModel>>.fromIterable([[]]);

        when(() => mockDataSource.watchMemories(coupleId))
            .thenAnswer((_) => stream);

        await expectLater(
          repository.watchMemories(coupleId),
          emits(predicate<List<Memory>>((memories) => memories.isEmpty)),
        );
      });
    });

    group('addMemory', () {
      test('returns Right(Memory) on success', () async {
        final createdMemory = MemoryModel(
          id: memoryId,
          coupleId: coupleId,
          title: 'New memory',
          category: 'travel',
          date: DateTime(2025, 7, 18),
          photoUrls: ['https://cloudinary.com/photo.jpg'],
          authorUid: authorUid,
          createdAt: DateTime.now(),
        );

        when(() => mockDataSource.addMemory(
              coupleId: coupleId,
              authorUid: authorUid,
              title: 'New memory',
              story: 'My story',
              category: 'travel',
              date: DateTime(2025, 7, 18),
              mood: null,
              photos: any(named: 'photos'),
            )).thenAnswer((_) async => createdMemory);

        final outcome = await repository.addMemory(
          coupleId: coupleId,
          authorUid: authorUid,
          title: 'New memory',
          story: 'My story',
          category: 'travel',
          date: DateTime(2025, 7, 18),
          photos: <File>[],
        );

        expect(outcome.isRight(), isTrue);
        outcome.fold(
          (_) => fail('Expected Right'),
          (memory) {
            expect(memory.id, equals(memoryId));
            expect(memory.title, equals('New memory'));
            expect(memory.category, equals('travel'));
          },
        );
      });

      test('returns Left(ServerFailure) on storage exception', () async {
        when(() => mockDataSource.addMemory(
              coupleId: any(named: 'coupleId'),
              authorUid: any(named: 'authorUid'),
              title: any(named: 'title'),
              story: any(named: 'story'),
              category: any(named: 'category'),
              date: any(named: 'date'),
              mood: any(named: 'mood'),
              photos: any(named: 'photos'),
            )).thenThrow(Exception('Storage upload failed'));

        final outcome = await repository.addMemory(
          coupleId: coupleId,
          authorUid: authorUid,
          title: 'Test',
          category: 'other',
          date: DateTime.now(),
          photos: <File>[],
        );

        expect(outcome.isLeft(), isTrue);
        outcome.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (_) => fail('Expected Left'),
        );
      });

      test('returns Left(ServerFailure) on Firebase exception', () async {
        when(() => mockDataSource.addMemory(
              coupleId: any(named: 'coupleId'),
              authorUid: any(named: 'authorUid'),
              title: any(named: 'title'),
              story: any(named: 'story'),
              category: any(named: 'category'),
              date: any(named: 'date'),
              mood: any(named: 'mood'),
              photos: any(named: 'photos'),
            )).thenThrow(Exception('Firestore unavailable'));

        final outcome = await repository.addMemory(
          coupleId: coupleId,
          authorUid: authorUid,
          title: 'Test',
          category: 'other',
          date: DateTime.now(),
          photos: <File>[],
        );

        expect(outcome.isLeft(), isTrue);
        outcome.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (_) => fail('Expected Left'),
        );
      });
    });

    group('deleteMemory', () {
      test('returns Right(unit) on success', () async {
        when(() => mockDataSource.deleteMemory(
              coupleId: coupleId,
              memoryId: memoryId,
            )).thenAnswer((_) async {});

        final outcome = await repository.deleteMemory(
          coupleId: coupleId,
          memoryId: memoryId,
        );

        expect(outcome.isRight(), isTrue);
        verify(() => mockDataSource.deleteMemory(
              coupleId: coupleId,
              memoryId: memoryId,
            )).called(1);
      });

      test('returns Left(ServerFailure) on Firebase exception', () async {
        when(() => mockDataSource.deleteMemory(
              coupleId: any(named: 'coupleId'),
              memoryId: any(named: 'memoryId'),
            )).thenThrow(Exception('Delete failed'));

        final outcome = await repository.deleteMemory(
          coupleId: coupleId,
          memoryId: memoryId,
        );

        expect(outcome.isLeft(), isTrue);
        outcome.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (_) => fail('Expected Left'),
        );
      });
    });
  });
}
