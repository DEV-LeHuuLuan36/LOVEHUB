import 'package:flutter_test/flutter_test.dart';
import 'package:lovehub/features/mood/domain/entities/mood_entry.dart';
import 'package:lovehub/features/mood/data/models/mood_entry_model.dart';
import 'package:lovehub/features/mood/domain/repositories/mood_repository.dart';
import 'package:lovehub/features/mood/data/repositories/mood_repository_impl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lovehub/features/mood/data/datasources/mood_remote_datasource.dart';

class _FakeSetMoodResult extends Fake implements SetMoodResult {}

class MockMoodRemoteDataSource extends Mock implements MoodRemoteDataSource {}

void main() {
  late MockMoodRemoteDataSource mockDataSource;
  late MoodRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(_FakeSetMoodResult());
  });

  setUp(() {
    mockDataSource = MockMoodRemoteDataSource();
    repository = MoodRepositoryImpl(remoteDataSource: mockDataSource);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 1. MoodEntry creation and properties
  // ─────────────────────────────────────────────────────────────────────────
  group('MoodEntry', () {
    test('creates instance with all required fields', () {
      final updatedAt = DateTime(2026, 7, 18, 10, 30);
      final entry = MoodEntry(
        uid: 'user_123',
        emoji: '😊',
        label: 'Happy',
        note: 'Great day!',
        updatedAt: updatedAt,
      );

      expect(entry.uid, equals('user_123'));
      expect(entry.emoji, equals('😊'));
      expect(entry.label, equals('Happy'));
      expect(entry.note, equals('Great day!'));
      expect(entry.updatedAt, equals(updatedAt));
    });

    test('note is optional and can be null', () {
      final entry = MoodEntry(
        uid: 'user_456',
        emoji: '😢',
        label: 'Sad',
        note: null,
        updatedAt: DateTime(2026, 7, 18),
      );

      expect(entry.note, isNull);
    });

    group('isPositive', () {
      test('true for Happy label', () {
        final entry = MoodEntry(
          uid: 'u1',
          emoji: '😊',
          label: 'Happy',
          updatedAt: DateTime.now(),
        );
        expect(entry.isPositive, isTrue);
      });

      test('true for In Love label', () {
        final entry = MoodEntry(
          uid: 'u1',
          emoji: '🥰',
          label: 'In Love',
          updatedAt: DateTime.now(),
        );
        expect(entry.isPositive, isTrue);
      });

      test('false for Sad label', () {
        final entry = MoodEntry(
          uid: 'u1',
          emoji: '😢',
          label: 'Sad',
          updatedAt: DateTime.now(),
        );
        expect(entry.isPositive, isFalse);
      });

      test('false for Neutral label', () {
        final entry = MoodEntry(
          uid: 'u1',
          emoji: '😐',
          label: 'Neutral',
          updatedAt: DateTime.now(),
        );
        expect(entry.isPositive, isFalse);
      });

      test('false for Angry label', () {
        final entry = MoodEntry(
          uid: 'u1',
          emoji: '😡',
          label: 'Angry',
          updatedAt: DateTime.now(),
        );
        expect(entry.isPositive, isFalse);
      });
    });

    group('equality', () {
      test('equal when uid, emoji, label, and note match', () {
        final updatedAt = DateTime(2026, 7, 18);
        final entry1 = MoodEntry(
          uid: 'u1',
          emoji: '😊',
          label: 'Happy',
          note: 'Nice',
          updatedAt: updatedAt,
        );
        final entry2 = MoodEntry(
          uid: 'u1',
          emoji: '😊',
          label: 'Happy',
          note: 'Nice',
          updatedAt: DateTime(2026, 8, 1), // different time, same identity
        );

        expect(entry1, equals(entry2));
        expect(entry1.hashCode, equals(entry2.hashCode));
      });

      test('not equal when uid differs', () {
        final entry1 = MoodEntry(
          uid: 'u1',
          emoji: '😊',
          label: 'Happy',
          updatedAt: DateTime.now(),
        );
        final entry2 = MoodEntry(
          uid: 'u2',
          emoji: '😊',
          label: 'Happy',
          updatedAt: DateTime.now(),
        );

        expect(entry1, isNot(equals(entry2)));
      });

      test('not equal when note differs (null vs non-null)', () {
        final entry1 = MoodEntry(
          uid: 'u1',
          emoji: '😊',
          label: 'Happy',
          note: null,
          updatedAt: DateTime.now(),
        );
        final entry2 = MoodEntry(
          uid: 'u1',
          emoji: '😊',
          label: 'Happy',
          note: 'Nice',
          updatedAt: DateTime.now(),
        );

        expect(entry1, isNot(equals(entry2)));
      });
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. MoodEntryModel fromJson / toJson round-trip
  // ─────────────────────────────────────────────────────────────────────────
  group('MoodEntryModel', () {
    test('fromFirestore constructs entry from map', () {
      final data = {
        'emoji': '🥰',
        'label': 'In Love',
        'note': 'Anniversary day!',
        'updatedAt': DateTime(2026, 7, 18, 14, 0),
      };

      final model = MoodEntryModel.fromFirestore('user_abc', data);

      expect(model.uid, equals('user_abc'));
      expect(model.emoji, equals('🥰'));
      expect(model.label, equals('In Love'));
      expect(model.note, equals('Anniversary day!'));
      expect(model.updatedAt, equals(DateTime(2026, 7, 18, 14, 0)));
    });

    test('fromFirestore handles null note', () {
      final data = {
        'emoji': '😢',
        'label': 'Sad',
        'note': null,
        'updatedAt': DateTime(2026, 7, 18),
      };

      final model = MoodEntryModel.fromFirestore('user_xyz', data);

      expect(model.note, isNull);
    });

    test('fromFirestore defaults empty/missing fields gracefully', () {
      final model = MoodEntryModel.fromFirestore('u1', {});

      expect(model.emoji, equals(''));
      expect(model.label, equals(''));
      expect(model.note, isNull);
    });

    test('toFirestore returns correct map', () {
      final updatedAt = DateTime(2026, 7, 18, 9, 30);
      final model = MoodEntryModel(
        uid: 'u1',
        emoji: '😊',
        label: 'Happy',
        note: 'Feeling great!',
        updatedAt: updatedAt,
      );

      final map = model.toFirestore();

      expect(map['emoji'], equals('😊'));
      expect(map['label'], equals('Happy'));
      expect(map['note'], equals('Feeling great!'));
      expect(map['updatedAt'], equals(updatedAt));
    });

    test('toFirestore includes null note as null', () {
      final model = MoodEntryModel(
        uid: 'u1',
        emoji: '😐',
        label: 'Neutral',
        note: null,
        updatedAt: DateTime(2026, 7, 18),
      );

      final map = model.toFirestore();

      expect(map.containsKey('note'), isTrue);
      expect(map['note'], isNull);
    });

    test('round-trip: model → toFirestore → fromFirestore preserves data', () {
      final original = MoodEntryModel(
        uid: 'user_roundtrip',
        emoji: '🥰',
        label: 'In Love',
        note: 'Best day ever',
        updatedAt: DateTime(2026, 7, 18, 20, 0),
      );

      final restored = MoodEntryModel.fromFirestore(
        'user_roundtrip',
        original.toFirestore(),
      );

      expect(restored.uid, equals(original.uid));
      expect(restored.emoji, equals(original.emoji));
      expect(restored.label, equals(original.label));
      expect(restored.note, equals(original.note));
      expect(restored.isPositive, equals(original.isPositive));
    });

    test('round-trip preserves null note', () {
      final original = MoodEntryModel(
        uid: 'u_null_note',
        emoji: '😡',
        label: 'Angry',
        note: null,
        updatedAt: DateTime(2026, 7, 18),
      );

      final restored = MoodEntryModel.fromFirestore(
        'u_null_note',
        original.toFirestore(),
      );

      expect(restored.note, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Date-based mood filtering logic
  // ─────────────────────────────────────────────────────────────────────────
  group('Date-based mood filtering', () {
    test('DailyMood date is preserved from creation', () {
      const daily = DailyMood(date: '2026-07-15');
      expect(daily.date, equals('2026-07-15'));
    });

    test('DailyMood with entries for specific date', () {
      final mine = MoodEntry(
        uid: 'u1',
        emoji: '😊',
        label: 'Happy',
        updatedAt: DateTime(2026, 7, 15, 8, 0),
      );
      final partner = MoodEntry(
        uid: 'u2',
        emoji: '🥰',
        label: 'In Love',
        updatedAt: DateTime(2026, 7, 15, 10, 0),
      );

      final daily = DailyMood(date: '2026-07-15', mine: mine, partner: partner);

      expect(daily.date, equals('2026-07-15'));
      expect(daily.mine, isNotNull);
      expect(daily.partner, isNotNull);
    });

    test('DailyMood with no entries for a date', () {
      const daily = DailyMood(date: '2026-07-10');
      expect(daily.date, equals('2026-07-10'));
      expect(daily.mine, isNull);
      expect(daily.partner, isNull);
    });

    test('DailyMood with only mine entry', () {
      final mine = MoodEntry(
        uid: 'u1',
        emoji: '😢',
        label: 'Sad',
        updatedAt: DateTime(2026, 7, 16),
      );

      final daily = DailyMood(date: '2026-07-16', mine: mine);

      expect(daily.mineSet, isTrue);
      expect(daily.partnerSet, isFalse);
    });

    test('DailyMood with only partner entry', () {
      final partner = MoodEntry(
        uid: 'u2',
        emoji: '😐',
        label: 'Neutral',
        updatedAt: DateTime(2026, 7, 16),
      );

      final daily = DailyMood(date: '2026-07-16', partner: partner);

      expect(daily.mineSet, isFalse);
      expect(daily.partnerSet, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Mood type validation
  // ─────────────────────────────────────────────────────────────────────────
  group('Mood type validation', () {
    test('isPositive correctly identifies Happy', () {
      final entry = MoodEntry(
        uid: 'u1',
        emoji: '😊',
        label: 'Happy',
        updatedAt: DateTime.now(),
      );
      expect(entry.isPositive, isTrue);
    });

    test('isPositive correctly identifies In Love', () {
      final entry = MoodEntry(
        uid: 'u1',
        emoji: '🥰',
        label: 'In Love',
        updatedAt: DateTime.now(),
      );
      expect(entry.isPositive, isTrue);
    });

    test('isPositive returns false for negative moods', () {
      final moods = [
        ('Sad', '😢'),
        ('Angry', '😡'),
        ('Neutral', '😐'),
      ];

      for (final (label, emoji) in moods) {
        final entry = MoodEntry(
          uid: 'u1',
          emoji: emoji,
          label: label,
          updatedAt: DateTime.now(),
        );
        expect(entry.isPositive, isFalse, reason: '$label should not be positive');
      }
    });

    test('MoodEntryModel inherits isPositive from MoodEntry', () {
      final happyModel = MoodEntryModel(
        uid: 'u1',
        emoji: '😊',
        label: 'Happy',
        updatedAt: DateTime.now(),
      );
      final sadModel = MoodEntryModel(
        uid: 'u2',
        emoji: '😢',
        label: 'Sad',
        updatedAt: DateTime.now(),
      );

      expect(happyModel.isPositive, isTrue);
      expect(sadModel.isPositive, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 5. Today's mood detection
  // ─────────────────────────────────────────────────────────────────────────
  group("Today's mood detection", () {
    test('mineSet is true when mine entry exists', () {
      final daily = DailyMood(
        date: '2026-07-18',
        mine: MoodEntry(
          uid: 'u1',
          emoji: '😊',
          label: 'Happy',
          updatedAt: DateTime.now(),
        ),
      );

      expect(daily.mineSet, isTrue);
    });

    test('mineSet is false when mine entry is null', () {
      const daily = DailyMood(date: '2026-07-18');
      expect(daily.mineSet, isFalse);
    });

    test('partnerSet is true when partner entry exists', () {
      final daily = DailyMood(
        date: '2026-07-18',
        partner: MoodEntry(
          uid: 'u2',
          emoji: '🥰',
          label: 'In Love',
          updatedAt: DateTime.now(),
        ),
      );

      expect(daily.partnerSet, isTrue);
    });

    test('partnerSet is false when partner entry is null', () {
      const daily = DailyMood(date: '2026-07-18');
      expect(daily.partnerSet, isFalse);
    });

    test('both partners set when both entries exist', () {
      final daily = DailyMood(
        date: '2026-07-18',
        mine: MoodEntry(
          uid: 'u1',
          emoji: '😊',
          label: 'Happy',
          updatedAt: DateTime.now(),
        ),
        partner: MoodEntry(
          uid: 'u2',
          emoji: '🥰',
          label: 'In Love',
          updatedAt: DateTime.now(),
        ),
      );

      expect(daily.mineSet, isTrue);
      expect(daily.partnerSet, isTrue);
    });

    test('neither set when both entries are null', () {
      const daily = DailyMood(date: '2026-07-18');
      expect(daily.mineSet, isFalse);
      expect(daily.partnerSet, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 6. Mood match bonus calculation (both positive)
  // ─────────────────────────────────────────────────────────────────────────
  group('Mood match bonus calculation', () {
    test('bothPositive true when both partners are Happy', () {
      final daily = DailyMood(
        date: '2026-07-18',
        mine: MoodEntry(
          uid: 'u1',
          emoji: '😊',
          label: 'Happy',
          updatedAt: DateTime.now(),
        ),
        partner: MoodEntry(
          uid: 'u2',
          emoji: '😊',
          label: 'Happy',
          updatedAt: DateTime.now(),
        ),
      );

      expect(daily.bothPositive, isTrue);
    });

    test('bothPositive true when both partners are In Love', () {
      final daily = DailyMood(
        date: '2026-07-18',
        mine: MoodEntry(
          uid: 'u1',
          emoji: '🥰',
          label: 'In Love',
          updatedAt: DateTime.now(),
        ),
        partner: MoodEntry(
          uid: 'u2',
          emoji: '🥰',
          label: 'In Love',
          updatedAt: DateTime.now(),
        ),
      );

      expect(daily.bothPositive, isTrue);
    });

    test('bothPositive true when mine Happy, partner In Love', () {
      final daily = DailyMood(
        date: '2026-07-18',
        mine: MoodEntry(
          uid: 'u1',
          emoji: '😊',
          label: 'Happy',
          updatedAt: DateTime.now(),
        ),
        partner: MoodEntry(
          uid: 'u2',
          emoji: '🥰',
          label: 'In Love',
          updatedAt: DateTime.now(),
        ),
      );

      expect(daily.bothPositive, isTrue);
    });

    test('bothPositive false when mine Happy, partner Sad', () {
      final daily = DailyMood(
        date: '2026-07-18',
        mine: MoodEntry(
          uid: 'u1',
          emoji: '😊',
          label: 'Happy',
          updatedAt: DateTime.now(),
        ),
        partner: MoodEntry(
          uid: 'u2',
          emoji: '😢',
          label: 'Sad',
          updatedAt: DateTime.now(),
        ),
      );

      expect(daily.bothPositive, isFalse);
    });

    test('bothPositive false when mine Sad, partner Happy', () {
      final daily = DailyMood(
        date: '2026-07-18',
        mine: MoodEntry(
          uid: 'u1',
          emoji: '😢',
          label: 'Sad',
          updatedAt: DateTime.now(),
        ),
        partner: MoodEntry(
          uid: 'u2',
          emoji: '😊',
          label: 'Happy',
          updatedAt: DateTime.now(),
        ),
      );

      expect(daily.bothPositive, isFalse);
    });

    test('bothPositive false when both are Sad', () {
      final daily = DailyMood(
        date: '2026-07-18',
        mine: MoodEntry(
          uid: 'u1',
          emoji: '😢',
          label: 'Sad',
          updatedAt: DateTime.now(),
        ),
        partner: MoodEntry(
          uid: 'u2',
          emoji: '😢',
          label: 'Sad',
          updatedAt: DateTime.now(),
        ),
      );

      expect(daily.bothPositive, isFalse);
    });

    test('bothPositive false when mine is null', () {
      final daily = DailyMood(
        date: '2026-07-18',
        mine: null,
        partner: MoodEntry(
          uid: 'u2',
          emoji: '😊',
          label: 'Happy',
          updatedAt: DateTime.now(),
        ),
      );

      expect(daily.bothPositive, isFalse);
    });

    test('bothPositive false when partner is null', () {
      final daily = DailyMood(
        date: '2026-07-18',
        mine: MoodEntry(
          uid: 'u1',
          emoji: '😊',
          label: 'Happy',
          updatedAt: DateTime.now(),
        ),
        partner: null,
      );

      expect(daily.bothPositive, isFalse);
    });

    test('bothPositive false when both are null', () {
      const daily = DailyMood(date: '2026-07-18');
      expect(daily.bothPositive, isFalse);
    });

    test('bonus calculation: +15 LP when bothPositive', () {
      const basePoints = 5;
      const matchBonus = 15;
      final daily = DailyMood(
        date: '2026-07-18',
        mine: MoodEntry(
          uid: 'u1',
          emoji: '😊',
          label: 'Happy',
          updatedAt: DateTime(2026, 7, 18),
        ),
        partner: MoodEntry(
          uid: 'u2',
          emoji: '🥰',
          label: 'In Love',
          updatedAt: DateTime(2026, 7, 18),
        ),
      );

      final totalPoints = daily.bothPositive ? basePoints + matchBonus : basePoints;

      expect(totalPoints, equals(20));
    });

    test('bonus calculation: only base LP when not bothPositive', () {
      const basePoints = 5;
      const matchBonus = 15;
      final daily = DailyMood(
        date: '2026-07-18',
        mine: MoodEntry(
          uid: 'u1',
          emoji: '😊',
          label: 'Happy',
          updatedAt: DateTime.now(),
        ),
        partner: MoodEntry(
          uid: 'u2',
          emoji: '😢',
          label: 'Sad',
          updatedAt: DateTime.now(),
        ),
      );

      final totalPoints = daily.bothPositive ? basePoints + matchBonus : basePoints;

      expect(totalPoints, equals(5));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MoodRepositoryImpl tests (mocked datasource)
  // ─────────────────────────────────────────────────────────────────────────
  group('MoodRepositoryImpl', () {
    const coupleId = 'couple_abc';
    const myUid = 'user_1';
    const partnerUid = 'user_2';

    group('watchTodayMood', () {
      test('delegates to datasource stream', () async {
        final stream = Stream<DailyMood>.fromIterable([
          const DailyMood(date: '2026-07-18'),
        ]);

        when(() => mockDataSource.watchTodayMood(coupleId, myUid, partnerUid))
            .thenAnswer((_) => stream);

        final result = repository.watchTodayMood(coupleId, myUid, partnerUid);

        await expectLater(result, emits(const DailyMood(date: '2026-07-18')));
        verify(() => mockDataSource.watchTodayMood(coupleId, myUid, partnerUid))
            .called(1);
      });

      test('emits empty DailyMood when no entry exists', () async {
        final stream = Stream<DailyMood>.fromIterable([
          const DailyMood(date: '2026-07-18'),
        ]);

        when(() => mockDataSource.watchTodayMood(coupleId, myUid, partnerUid))
            .thenAnswer((_) => stream);

        await expectLater(
          repository.watchTodayMood(coupleId, myUid, partnerUid),
          emits(predicate<DailyMood>(
            (daily) => daily.mine == null && daily.partner == null,
          )),
        );
      });
    });

    group('watchRecentMoods', () {
      test('delegates to datasource with default days=14', () async {
        final moods = [
          const DailyMood(date: '2026-07-18'),
          const DailyMood(date: '2026-07-17'),
        ];
        final stream = Stream<List<DailyMood>>.fromIterable([moods]);

        when(() => mockDataSource.watchRecentMoods(
              coupleId,
              myUid: myUid,
              partnerUid: partnerUid,
              days: 14,
            )).thenAnswer((_) => stream);

        final result = repository.watchRecentMoods(
          coupleId,
          myUid: myUid,
          partnerUid: partnerUid,
        );

        await expectLater(
          result,
          emits(equals(moods)),
        );
      });

      test('passes custom days parameter', () {
        final stream = Stream<List<DailyMood>>.empty();

        when(() => mockDataSource.watchRecentMoods(
              coupleId,
              myUid: myUid,
              partnerUid: partnerUid,
              days: 7,
            )).thenAnswer((_) => stream);

        repository.watchRecentMoods(
          coupleId,
          myUid: myUid,
          partnerUid: partnerUid,
          days: 7,
        );

        verify(() => mockDataSource.watchRecentMoods(
              coupleId,
              myUid: myUid,
              partnerUid: partnerUid,
              days: 7,
            )).called(1);
      });
    });

    group('setMood', () {
      test('returns Right(SetMoodResult) on success', () async {
        const result = SetMoodResult(lpAwarded: true, firstToday: true);
        when(() => mockDataSource.setMood(
              coupleId: coupleId,
              uid: myUid,
              emoji: '😊',
              label: 'Happy',
              note: 'Great day!',
            )).thenAnswer((_) async => result);

        final outcome = await repository.setMood(
          coupleId: coupleId,
          uid: myUid,
          emoji: '😊',
          label: 'Happy',
          note: 'Great day!',
        );

        expect(outcome.isRight(), isTrue);
        outcome.fold(
          (_) => fail('Expected Right'),
          (r) {
            expect(r.lpAwarded, isTrue);
            expect(r.firstToday, isTrue);
          },
        );
      });

      test('returns Left(ServerFailure) on FirebaseException', () async {
        when(() => mockDataSource.setMood(
              coupleId: coupleId,
              uid: myUid,
              emoji: '😊',
              label: 'Happy',
              note: null,
            )).thenThrow(Exception('Firestore offline'));

        final outcome = await repository.setMood(
          coupleId: coupleId,
          uid: myUid,
          emoji: '😊',
          label: 'Happy',
        );

        expect(outcome.isLeft(), isTrue);
      });

      test('lpAwarded is false when not first mood of the day', () async {
        const result = SetMoodResult(lpAwarded: false, firstToday: false);
        when(() => mockDataSource.setMood(
              coupleId: coupleId,
              uid: myUid,
              emoji: '😊',
              label: 'Happy',
              note: null,
            )).thenAnswer((_) async => result);

        final outcome = await repository.setMood(
          coupleId: coupleId,
          uid: myUid,
          emoji: '😊',
          label: 'Happy',
        );

        outcome.fold(
          (_) => fail('Expected Right'),
          (r) => expect(r.lpAwarded, isFalse),
        );
      });
    });
  });
}
