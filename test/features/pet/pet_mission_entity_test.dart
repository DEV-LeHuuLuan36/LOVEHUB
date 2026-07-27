import 'package:flutter_test/flutter_test.dart';
import 'package:lovehub/features/gamification/domain/entities/pet_mission_entity.dart';

void main() {
  group('PetMissionEntity', () {
    group('fedToday', () {
      test('true when lastFeedDate equals today', () {
        // Pin "today" so we get a deterministic answer.
        PetMissionEntity.setTodayOverride('2026-07-17');
        addTearDown(() => PetMissionEntity.setTodayOverride(null));

        final entity = PetMissionEntity(
          coupleId: 'c1',
          lastFeedDate: '2026-07-17',
        );

        expect(entity.fedToday, isTrue);
      });

      test('false when lastFeedDate is yesterday', () {
        PetMissionEntity.setTodayOverride('2026-07-17');
        addTearDown(() => PetMissionEntity.setTodayOverride(null));

        final entity = PetMissionEntity(
          coupleId: 'c1',
          lastFeedDate: '2026-07-16',
        );

        expect(entity.fedToday, isFalse);
      });

      test('false when lastFeedDate is null', () {
        PetMissionEntity.setTodayOverride('2026-07-17');
        addTearDown(() => PetMissionEntity.setTodayOverride(null));

        final entity = PetMissionEntity(coupleId: 'c1');

        expect(entity.fedToday, isFalse);
      });

      test('false when lastFeedDate is days ago', () {
        PetMissionEntity.setTodayOverride('2026-07-17');
        addTearDown(() => PetMissionEntity.setTodayOverride(null));

        final entity = PetMissionEntity(
          coupleId: 'c1',
          lastFeedDate: '2026-07-10',
        );

        expect(entity.fedToday, isFalse);
      });
    });

    group('patPetDoneToday', () {
      test('true when patCount >= maxPatPerDay and lastPatDate is today', () {
        PetMissionEntity.setTodayOverride('2026-07-17');
        addTearDown(() => PetMissionEntity.setTodayOverride(null));

        final entity = PetMissionEntity(
          coupleId: 'c1',
          patCount: 5,
          lastPatDate: '2026-07-17',
        );

        expect(entity.patPetDoneToday(5), isTrue);
      });

      test('true when patCount > maxPatPerDay', () {
        PetMissionEntity.setTodayOverride('2026-07-17');
        addTearDown(() => PetMissionEntity.setTodayOverride(null));

        final entity = PetMissionEntity(
          coupleId: 'c1',
          patCount: 10,
          lastPatDate: '2026-07-17',
        );

        expect(entity.patPetDoneToday(5), isTrue);
      });

      test('false when patCount < maxPatPerDay even with today date', () {
        PetMissionEntity.setTodayOverride('2026-07-17');
        addTearDown(() => PetMissionEntity.setTodayOverride(null));

        final entity = PetMissionEntity(
          coupleId: 'c1',
          patCount: 3,
          lastPatDate: '2026-07-17',
        );

        expect(entity.patPetDoneToday(5), isFalse);
      });

      test('false when lastPatDate is yesterday even with high patCount', () {
        PetMissionEntity.setTodayOverride('2026-07-17');
        addTearDown(() => PetMissionEntity.setTodayOverride(null));

        final entity = PetMissionEntity(
          coupleId: 'c1',
          patCount: 5,
          lastPatDate: '2026-07-16',
        );

        expect(entity.patPetDoneToday(5), isFalse);
      });

      test('false when lastPatDate is null', () {
        PetMissionEntity.setTodayOverride('2026-07-17');
        addTearDown(() => PetMissionEntity.setTodayOverride(null));

        final entity = PetMissionEntity(coupleId: 'c1', patCount: 5);

        expect(entity.patPetDoneToday(5), isFalse);
      });
    });

    group('setTodayOverride (test helper)', () {
      test('overrides the effective "today" date', () {
        PetMissionEntity.setTodayOverride('2025-01-01');
        addTearDown(() => PetMissionEntity.setTodayOverride(null));

        final entity = PetMissionEntity(
          coupleId: 'c1',
          lastFeedDate: '2025-01-01',
          patCount: 5,
          lastPatDate: '2025-01-01',
        );

        expect(entity.fedToday, isTrue);
        expect(entity.patPetDoneToday(5), isTrue);
      });

      test('null override restores real clock', () {
        // Set to a known date, then clear.
        PetMissionEntity.setTodayOverride('2020-01-01');
        PetMissionEntity.setTodayOverride(null);

        // Now fedToday should use the real clock.
        final now = DateTime.now();
        final today = '${now.year}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';

        final entity = PetMissionEntity(
          coupleId: 'c1',
          lastFeedDate: today,
        );

        expect(entity.fedToday, isTrue);
      });
    });
  });
}
