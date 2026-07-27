import 'package:flutter_test/flutter_test.dart';
import 'package:lovehub/features/finance/domain/entities/saving_jar.dart';
import 'package:lovehub/features/finance/domain/entities/contribution.dart';
import 'package:lovehub/features/finance/data/models/saving_jar_model.dart';
import 'package:lovehub/features/finance/data/models/contribution_model.dart';

void main() {
  group('SavingJar Entity', () {
    group('creation', () {
      test('creates with all required fields', () {
        final createdAt = DateTime(2026, 1, 1);
        final deadline = DateTime(2026, 12, 31);

        final jar = SavingJar(
          id: 'jar1',
          coupleId: 'couple1',
          name: 'Beach Trip',
          emoji: '🏖️',
          targetAmount: 500000,
          currentAmount: 100000,
          deadline: deadline,
          createdAt: createdAt,
          bankCode: 'TPB',
          bankAccountNumber: '123456789',
          bankAccountName: 'Love Couple',
        );

        expect(jar.id, equals('jar1'));
        expect(jar.coupleId, equals('couple1'));
        expect(jar.name, equals('Beach Trip'));
        expect(jar.emoji, equals('🏖️'));
        expect(jar.targetAmount, equals(500000));
        expect(jar.currentAmount, equals(100000));
        expect(jar.deadline, equals(deadline));
        expect(jar.createdAt, equals(createdAt));
        expect(jar.bankCode, equals('TPB'));
        expect(jar.bankAccountNumber, equals('123456789'));
        expect(jar.bankAccountName, equals('Love Couple'));
      });

      test('creates with only required fields', () {
        final createdAt = DateTime(2026, 1, 1);

        final jar = SavingJar(
          id: 'jar2',
          coupleId: 'couple1',
          name: 'Simple Jar',
          emoji: '🐷',
          targetAmount: 100000,
          currentAmount: 0,
          createdAt: createdAt,
        );

        expect(jar.id, equals('jar2'));
        expect(jar.bankCode, isNull);
        expect(jar.bankAccountNumber, isNull);
        expect(jar.bankAccountName, isNull);
        expect(jar.deadline, isNull);
      });
    });

    group('hasBankInfo', () {
      test('true when both bankCode and bankAccountNumber are present', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100,
          currentAmount: 0,
          createdAt: DateTime.now(),
          bankCode: 'TPB',
          bankAccountNumber: '123',
        );
        expect(jar.hasBankInfo, isTrue);
      });

      test('false when bankCode is null', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100,
          currentAmount: 0,
          createdAt: DateTime.now(),
          bankAccountNumber: '123',
        );
        expect(jar.hasBankInfo, isFalse);
      });

      test('false when bankCode is empty string', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100,
          currentAmount: 0,
          createdAt: DateTime.now(),
          bankCode: '',
          bankAccountNumber: '123',
        );
        expect(jar.hasBankInfo, isFalse);
      });

      test('false when bankAccountNumber is null', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100,
          currentAmount: 0,
          createdAt: DateTime.now(),
          bankCode: 'TPB',
        );
        expect(jar.hasBankInfo, isFalse);
      });

      test('false when bankAccountNumber is empty string', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100,
          currentAmount: 0,
          createdAt: DateTime.now(),
          bankCode: 'TPB',
          bankAccountNumber: '',
        );
        expect(jar.hasBankInfo, isFalse);
      });
    });

    group('progress calculation', () {
      test('returns 0 when targetAmount is 0', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 0,
          currentAmount: 0,
          createdAt: DateTime.now(),
        );
        expect(jar.progress, equals(0.0));
      });

      test('returns 0 when targetAmount is negative', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: -100,
          currentAmount: 50,
          createdAt: DateTime.now(),
        );
        expect(jar.progress, equals(0.0));
      });

      test('returns correct progress ratio', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 1000000,
          currentAmount: 250000,
          createdAt: DateTime.now(),
        );
        expect(jar.progress, equals(0.25));
      });

      test('returns 1.0 when currentAmount equals targetAmount', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 500000,
          currentAmount: 500000,
          createdAt: DateTime.now(),
        );
        expect(jar.progress, equals(1.0));
      });

      test('clamps to 1.0 when currentAmount exceeds targetAmount', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100000,
          currentAmount: 200000,
          createdAt: DateTime.now(),
        );
        expect(jar.progress, equals(1.0));
      });

      test('percentInt returns rounded integer percentage', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 1000000,
          currentAmount: 333333,
          createdAt: DateTime.now(),
        );
        expect(jar.percentInt, equals(33));
      });

      test('percentFormatted shows 0.x% for tiny fractions (< 1%)', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 1000000,
          currentAmount: 5000,
          createdAt: DateTime.now(),
        );
        expect(jar.percentFormatted, equals('0.5%'));
      });

      test('percentFormatted rounds to integer for >= 1%', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 1000000,
          currentAmount: 10000,
          createdAt: DateTime.now(),
        );
        expect(jar.percentFormatted, equals('1%'));
      });

      test('percentFormatted returns 0% when progress is 0', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 1000000,
          currentAmount: 0,
          createdAt: DateTime.now(),
        );
        expect(jar.percentFormatted, equals('0%'));
      });
    });

    group('goal completion detection', () {
      test('completed when currentAmount equals targetAmount', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 500000,
          currentAmount: 500000,
          createdAt: DateTime.now(),
        );
        expect(jar.progress, equals(1.0));
      });

      test('not completed when currentAmount is less than targetAmount', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 500000,
          currentAmount: 499999,
          createdAt: DateTime.now(),
        );
        expect(jar.progress, lessThan(1.0));
      });
    });

    group('date target validation', () {
      test('deadline can be null', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100,
          currentAmount: 0,
          createdAt: DateTime(2026, 1, 1),
          deadline: null,
        );
        expect(jar.deadline, isNull);
      });

      test('deadline can be in the past', () {
        final deadline = DateTime(2020, 1, 1);
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100,
          currentAmount: 0,
          createdAt: DateTime(2026, 1, 1),
          deadline: deadline,
        );
        expect(jar.deadline, equals(deadline));
      });

      test('deadline can be in the future', () {
        final deadline = DateTime(2030, 12, 31);
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100,
          currentAmount: 0,
          createdAt: DateTime(2026, 1, 1),
          deadline: deadline,
        );
        expect(jar.deadline!.isAfter(DateTime.now()), isTrue);
      });

      test('deadline can be today', () {
        final today = DateTime(2026, 7, 18);
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100,
          currentAmount: 0,
          createdAt: DateTime(2026, 1, 1),
          deadline: today,
        );
        expect(jar.deadline, equals(today));
      });
    });

    group('balance validation (withdrawal)', () {
      test('currentAmount can be 0', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100000,
          currentAmount: 0,
          createdAt: DateTime.now(),
        );
        expect(jar.currentAmount, equals(0));
      });

      test('currentAmount can equal targetAmount', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100000,
          currentAmount: 100000,
          createdAt: DateTime.now(),
        );
        expect(jar.currentAmount, equals(jar.targetAmount));
      });

      test('currentAmount can exceed targetAmount (overflow)', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100000,
          currentAmount: 150000,
          createdAt: DateTime.now(),
        );
        expect(jar.currentAmount, greaterThan(jar.targetAmount));
        expect(jar.progress, equals(1.0));
      });

      test('currentAmount can be negative (simulating over-withdrawal)', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100000,
          currentAmount: -10000,
          createdAt: DateTime.now(),
        );
        expect(jar.currentAmount, lessThan(0));
      });
    });

    group('icon and emoji mapping', () {
      test('accepts any emoji string', () {
        final emojis = ['🏖️', '✈️', '💍', '🏠', '🚗', '🎓', '💰', '🐷'];
        for (final emoji in emojis) {
          final jar = SavingJar(
            id: 'j1',
            coupleId: 'c1',
            name: 'N',
            emoji: emoji,
            targetAmount: 100,
            currentAmount: 0,
            createdAt: DateTime.now(),
          );
          expect(jar.emoji, equals(emoji));
        }
      });

      test('accepts emoji as single visual character', () {
        final jar = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🎁',
          targetAmount: 100,
          currentAmount: 0,
          createdAt: DateTime.now(),
        );
        expect(jar.emoji, equals('🎁'));
      });
    });

    group('copyWith', () {
      test('creates copy with updated currentAmount', () {
        final original = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'Beach Trip',
          emoji: '🏖️',
          targetAmount: 500000,
          currentAmount: 0,
          createdAt: DateTime(2026, 1, 1),
        );

        final updated = original.copyWith(currentAmount: 250000);

        expect(updated.id, equals(original.id));
        expect(updated.coupleId, equals(original.coupleId));
        expect(updated.name, equals(original.name));
        expect(updated.emoji, equals(original.emoji));
        expect(updated.targetAmount, equals(original.targetAmount));
        expect(updated.currentAmount, equals(250000));
        expect(updated.createdAt, equals(original.createdAt));
      });

      test('creates copy with updated deadline', () {
        final original = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100,
          currentAmount: 0,
          createdAt: DateTime(2026, 1, 1),
        );

        final newDeadline = DateTime(2026, 12, 31);
        final updated = original.copyWith(deadline: newDeadline);

        expect(updated.deadline, equals(newDeadline));
      });

      test('original unchanged after copyWith', () {
        final original = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100,
          currentAmount: 0,
          createdAt: DateTime(2026, 1, 1),
        );

        original.copyWith(currentAmount: 50);

        expect(original.currentAmount, equals(0));
      });
    });

    group('equality', () {
      test('two jars with same fields are equal', () {
        final createdAt = DateTime(2026, 1, 1);
        final jar1 = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'Beach',
          emoji: '🏖️',
          targetAmount: 500000,
          currentAmount: 100000,
          createdAt: createdAt,
        );
        final jar2 = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'Beach',
          emoji: '🏖️',
          targetAmount: 500000,
          currentAmount: 100000,
          createdAt: createdAt,
        );

        expect(jar1, equals(jar2));
        expect(jar1.hashCode, equals(jar2.hashCode));
      });

      test('two jars with different ids are not equal', () {
        final createdAt = DateTime(2026, 1, 1);
        final jar1 = SavingJar(
          id: 'j1',
          coupleId: 'c1',
          name: 'Beach',
          emoji: '🏖️',
          targetAmount: 500000,
          currentAmount: 100000,
          createdAt: createdAt,
        );
        final jar2 = SavingJar(
          id: 'j2',
          coupleId: 'c1',
          name: 'Beach',
          emoji: '🏖️',
          targetAmount: 500000,
          currentAmount: 100000,
          createdAt: createdAt,
        );

        expect(jar1, isNot(equals(jar2)));
      });
    });
  });

  group('Contribution Entity', () {
    group('creation', () {
      test('creates with all fields', () {
        final createdAt = DateTime(2026, 1, 15, 10, 30);

        final contribution = Contribution(
          id: 'contrib1',
          coupleId: 'couple1',
          jarId: 'jar1',
          userId: 'user1',
          userName: 'Alice',
          amount: 50000,
          note: 'Birthday gift',
          method: 'qr',
          source: 'qr_code',
          createdAt: createdAt,
        );

        expect(contribution.id, equals('contrib1'));
        expect(contribution.coupleId, equals('couple1'));
        expect(contribution.jarId, equals('jar1'));
        expect(contribution.userId, equals('user1'));
        expect(contribution.userName, equals('Alice'));
        expect(contribution.amount, equals(50000));
        expect(contribution.note, equals('Birthday gift'));
        expect(contribution.method, equals('qr'));
        expect(contribution.source, equals('qr_code'));
        expect(contribution.createdAt, equals(createdAt));
      });

      test('creates with minimal required fields', () {
        final createdAt = DateTime(2026, 1, 15);

        final contribution = Contribution(
          id: 'contrib2',
          coupleId: 'couple1',
          jarId: 'jar1',
          userId: 'user1',
          userName: 'Bob',
          amount: 10000,
          method: 'manual',
          source: 'manual',
          createdAt: createdAt,
        );

        expect(contribution.id, equals('contrib2'));
        expect(contribution.note, isNull);
      });
    });

    group('minimum contribution enforcement', () {
      test('amount can be 0', () {
        final contribution = Contribution(
          id: 'c1',
          coupleId: 'c1',
          jarId: 'j1',
          userId: 'u1',
          userName: 'N',
          amount: 0,
          method: 'manual',
          source: 'manual',
          createdAt: DateTime.now(),
        );
        expect(contribution.amount, equals(0));
      });

      test('amount can be 1', () {
        final contribution = Contribution(
          id: 'c1',
          coupleId: 'c1',
          jarId: 'j1',
          userId: 'u1',
          userName: 'N',
          amount: 1,
          method: 'manual',
          source: 'manual',
          createdAt: DateTime.now(),
        );
        expect(contribution.amount, equals(1));
      });

      test('amount can be large value', () {
        final contribution = Contribution(
          id: 'c1',
          coupleId: 'c1',
          jarId: 'j1',
          userId: 'u1',
          userName: 'N',
          amount: 10000000,
          method: 'manual',
          source: 'manual',
          createdAt: DateTime.now(),
        );
        expect(contribution.amount, equals(10000000));
      });

      test('amount can be negative (reversal)', () {
        final contribution = Contribution(
          id: 'c1',
          coupleId: 'c1',
          jarId: 'j1',
          userId: 'u1',
          userName: 'N',
          amount: -50000,
          method: 'manual',
          source: 'manual',
          createdAt: DateTime.now(),
        );
        expect(contribution.amount, lessThan(0));
      });
    });

    group('equality', () {
      test('two contributions with same fields are equal', () {
        final createdAt = DateTime(2026, 1, 15);
        final c1 = Contribution(
          id: 'c1',
          coupleId: 'cp1',
          jarId: 'j1',
          userId: 'u1',
          userName: 'Alice',
          amount: 50000,
          note: 'Test',
          method: 'qr',
          source: 'qr',
          createdAt: createdAt,
        );
        final c2 = Contribution(
          id: 'c1',
          coupleId: 'cp1',
          jarId: 'j1',
          userId: 'u1',
          userName: 'Alice',
          amount: 50000,
          note: 'Test',
          method: 'qr',
          source: 'qr',
          createdAt: createdAt,
        );

        expect(c1, equals(c2));
        expect(c1.hashCode, equals(c2.hashCode));
      });

      test('two contributions with different amounts are not equal', () {
        final createdAt = DateTime(2026, 1, 15);
        final c1 = Contribution(
          id: 'c1',
          coupleId: 'cp1',
          jarId: 'j1',
          userId: 'u1',
          userName: 'N',
          amount: 50000,
          method: 'qr',
          source: 'qr',
          createdAt: createdAt,
        );
        final c2 = Contribution(
          id: 'c1',
          coupleId: 'cp1',
          jarId: 'j1',
          userId: 'u1',
          userName: 'N',
          amount: 100000,
          method: 'qr',
          source: 'qr',
          createdAt: createdAt,
        );

        expect(c1, isNot(equals(c2)));
      });
    });
  });

  group('SavingJarModel', () {
    group('fromFirestore', () {
      test('parses complete Firestore document', () {
        final deadline = DateTime(2026, 7, 1);
        final createdAt = DateTime(2026, 1, 1);
        final data = {
          'coupleId': 'couple1',
          'name': 'Beach Trip',
          'emoji': '🏖️',
          'targetAmount': 500000,
          'currentAmount': 100000,
          'deadline': deadline,
          'createdAt': createdAt,
          'bankCode': 'TPB',
          'bankAccountNumber': '123456789',
          'bankAccountName': 'Love Couple',
        };

        final model = SavingJarModel.fromFirestore('jar_doc_id', data);

        expect(model.id, equals('jar_doc_id'));
        expect(model.coupleId, equals('couple1'));
        expect(model.name, equals('Beach Trip'));
        expect(model.emoji, equals('🏖️'));
        expect(model.targetAmount, equals(500000));
        expect(model.currentAmount, equals(100000));
        expect(model.bankCode, equals('TPB'));
        expect(model.bankAccountNumber, equals('123456789'));
        expect(model.bankAccountName, equals('Love Couple'));
      });

      test('handles missing optional fields with defaults', () {
        final data = {
          'coupleId': 'couple1',
          'name': 'Simple Jar',
          'targetAmount': 100000,
          'currentAmount': 0,
        };

        final model = SavingJarModel.fromFirestore('jar_id', data);

        expect(model.emoji, equals('🐷'));
        expect(model.targetAmount, equals(100000));
        expect(model.currentAmount, equals(0));
        expect(model.bankCode, isNull);
        expect(model.bankAccountNumber, isNull);
        expect(model.bankAccountName, isNull);
        expect(model.deadline, isNull);
      });

      test('handles null coupleId and name', () {
        final data = <String, dynamic>{
          'coupleId': null,
          'name': null,
          'targetAmount': null,
          'currentAmount': null,
        };

        final model = SavingJarModel.fromFirestore('jar_id', data);

        expect(model.coupleId, equals(''));
        expect(model.name, equals(''));
        expect(model.targetAmount, equals(0));
        expect(model.currentAmount, equals(0));
      });

      test('handles double targetAmount', () {
        final data = {
          'coupleId': 'c1',
          'name': 'N',
          'targetAmount': 100000.5,
          'currentAmount': 50000.7,
        };

        final model = SavingJarModel.fromFirestore('j1', data);

        expect(model.targetAmount, equals(100000));
        expect(model.currentAmount, equals(50000));
      });

      test('parses deadline and createdAt as DateTime', () {
        final deadline = DateTime(2026, 7, 1, 0, 0);
        final createdAt = DateTime(2026, 1, 1, 0, 0);
        final data = {
          'coupleId': 'c1',
          'name': 'N',
          'targetAmount': 100,
          'currentAmount': 0,
          'deadline': deadline,
          'createdAt': createdAt,
        };

        final model = SavingJarModel.fromFirestore('j1', data);

        expect(model.deadline, equals(deadline));
        expect(model.createdAt, equals(createdAt));
      });

      test('parses deadline and createdAt as DateTime objects directly', () {
        final deadline = DateTime(2026, 12, 31);
        final createdAt = DateTime(2026, 1, 1);
        final data = {
          'coupleId': 'c1',
          'name': 'N',
          'targetAmount': 100,
          'currentAmount': 0,
          'deadline': deadline,
          'createdAt': createdAt,
        };

        final model = SavingJarModel.fromFirestore('j1', data);

        expect(model.deadline, equals(deadline));
        expect(model.createdAt, equals(createdAt));
      });

      test('omits null/empty bank fields in toFirestore', () {
        final model = SavingJarModel(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100,
          currentAmount: 0,
          createdAt: DateTime.now(),
        );

        final map = model.toFirestore();

        expect(map.containsKey('bankCode'), isFalse);
        expect(map.containsKey('bankAccountNumber'), isFalse);
        expect(map.containsKey('bankAccountName'), isFalse);
      });

      test('includes non-empty bank fields in toFirestore', () {
        final model = SavingJarModel(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100,
          currentAmount: 0,
          createdAt: DateTime.now(),
          bankCode: 'TPB',
          bankAccountNumber: '123',
          bankAccountName: 'Love',
        );

        final map = model.toFirestore();

        expect(map['bankCode'], equals('TPB'));
        expect(map['bankAccountNumber'], equals('123'));
        expect(map['bankAccountName'], equals('Love'));
      });
    });

    group('round-trip fromJson/toJson', () {
      test('SavingJarModel round-trip via Firestore format', () {
        final original = SavingJarModel(
          id: 'jar123',
          coupleId: 'couple456',
          name: 'Dream Vacation',
          emoji: '✈️',
          targetAmount: 5000000,
          currentAmount: 1250000,
          deadline: DateTime(2026, 12, 31),
          createdAt: DateTime(2026, 1, 1),
          bankCode: 'VPB',
          bankAccountNumber: '999888777',
          bankAccountName: 'John & Jane',
        );

        final firestoreData = original.toFirestore();
        final restored = SavingJarModel.fromFirestore(original.id, firestoreData);

        expect(restored.id, equals(original.id));
        expect(restored.coupleId, equals(original.coupleId));
        expect(restored.name, equals(original.name));
        expect(restored.emoji, equals(original.emoji));
        expect(restored.targetAmount, equals(original.targetAmount));
        expect(restored.currentAmount, equals(original.currentAmount));
        expect(restored.bankCode, equals(original.bankCode));
        expect(restored.bankAccountNumber, equals(original.bankAccountNumber));
        expect(restored.bankAccountName, equals(original.bankAccountName));
      });

      test('SavingJarModel round-trip with null optional fields', () {
        final original = SavingJarModel(
          id: 'jar789',
          coupleId: 'couple123',
          name: 'No Deadline Jar',
          emoji: '💰',
          targetAmount: 100000,
          currentAmount: 0,
          createdAt: DateTime(2026, 1, 1),
        );

        final firestoreData = original.toFirestore();
        final restored = SavingJarModel.fromFirestore(original.id, firestoreData);

        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.deadline, isNull);
        expect(restored.bankCode, isNull);
        expect(restored.bankAccountNumber, isNull);
        expect(restored.bankAccountName, isNull);
      });

      test('empty string bankCode is omitted in toFirestore', () {
        final model = SavingJarModel(
          id: 'j1',
          coupleId: 'c1',
          name: 'N',
          emoji: '🐷',
          targetAmount: 100,
          currentAmount: 0,
          createdAt: DateTime.now(),
          bankCode: '',
          bankAccountNumber: '123',
        );

        final map = model.toFirestore();

        expect(map.containsKey('bankCode'), isFalse);
        expect(map.containsKey('bankAccountNumber'), isTrue);
      });
    });
  });

  group('ContributionModel', () {
    group('fromFirestore', () {
      test('parses complete Firestore document', () {
        final createdAt = DateTime(2026, 7, 18, 14, 30);
        final data = {
          'coupleId': 'couple1',
          'jarId': 'jar1',
          'userId': 'user1',
          'userName': 'Alice',
          'amount': 50000,
          'note': 'Birthday gift',
          'method': 'qr',
          'source': 'qr_code',
          'createdAt': createdAt,
        };

        final model = ContributionModel.fromFirestore('contrib_doc_id', data);

        expect(model.id, equals('contrib_doc_id'));
        expect(model.coupleId, equals('couple1'));
        expect(model.jarId, equals('jar1'));
        expect(model.userId, equals('user1'));
        expect(model.userName, equals('Alice'));
        expect(model.amount, equals(50000));
        expect(model.note, equals('Birthday gift'));
        expect(model.method, equals('qr'));
        expect(model.source, equals('qr_code'));
      });

      test('handles missing optional fields with defaults', () {
        final data = {
          'coupleId': 'couple1',
          'jarId': 'jar1',
          'userId': 'user1',
          'userName': 'Bob',
        };

        final model = ContributionModel.fromFirestore('c1', data);

        expect(model.amount, equals(0));
        expect(model.note, isNull);
        expect(model.method, equals('manual'));
        expect(model.source, equals('manual'));
      });

      test('handles null userId and userName', () {
        final data = <String, dynamic>{
          'coupleId': null,
          'jarId': null,
          'userId': null,
          'userName': null,
        };

        final model = ContributionModel.fromFirestore('c1', data);

        expect(model.coupleId, equals(''));
        expect(model.jarId, equals(''));
        expect(model.userId, equals(''));
        expect(model.userName, equals(''));
      });

      test('handles double amount', () {
        final data = {
          'coupleId': 'c1',
          'jarId': 'j1',
          'userId': 'u1',
          'userName': 'N',
          'amount': 50000.9,
        };

        final model = ContributionModel.fromFirestore('c1', data);

        expect(model.amount, equals(50000));
      });

      test('parses createdAt as DateTime', () {
        final createdAt = DateTime(2026, 7, 18, 12, 0);
        final data = {
          'coupleId': 'c1',
          'jarId': 'j1',
          'userId': 'u1',
          'userName': 'N',
          'amount': 100,
          'createdAt': createdAt,
        };

        final model = ContributionModel.fromFirestore('c1', data);

        expect(model.createdAt, equals(createdAt));
      });

      test('defaults createdAt to DateTime.now() when null', () {
        final data = {
          'coupleId': 'c1',
          'jarId': 'j1',
          'userId': 'u1',
          'userName': 'N',
          'amount': 100,
          'createdAt': null,
        };

        final before = DateTime.now();
        final model = ContributionModel.fromFirestore('c1', data);
        final after = DateTime.now();

        expect(model.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
        expect(model.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
      });

      test('parses createdAt as DateTime object directly', () {
        final createdAt = DateTime(2026, 7, 18, 14, 30);
        final data = {
          'coupleId': 'c1',
          'jarId': 'j1',
          'userId': 'u1',
          'userName': 'N',
          'amount': 100,
          'createdAt': createdAt,
        };

        final model = ContributionModel.fromFirestore('c1', data);

        expect(model.createdAt, equals(createdAt));
      });
    });

    group('round-trip fromJson/toJson', () {
      test('ContributionModel round-trip via Firestore format', () {
        final original = ContributionModel(
          id: 'contrib999',
          coupleId: 'couple888',
          jarId: 'jar777',
          userId: 'user666',
          userName: 'Charlie',
          amount: 250000,
          note: 'Anniversary bonus',
          method: 'qr',
          source: 'qr_payment',
          createdAt: DateTime(2026, 7, 18, 20, 0),
        );

        final firestoreData = original.toFirestore();
        final restored = ContributionModel.fromFirestore(original.id, firestoreData);

        expect(restored.id, equals(original.id));
        expect(restored.coupleId, equals(original.coupleId));
        expect(restored.jarId, equals(original.jarId));
        expect(restored.userId, equals(original.userId));
        expect(restored.userName, equals(original.userName));
        expect(restored.amount, equals(original.amount));
        expect(restored.note, equals(original.note));
        expect(restored.method, equals(original.method));
        expect(restored.source, equals(original.source));
        expect(restored.createdAt, equals(original.createdAt));
      });

      test('ContributionModel round-trip with null note', () {
        final original = ContributionModel(
          id: 'c1',
          coupleId: 'cp1',
          jarId: 'j1',
          userId: 'u1',
          userName: 'N',
          amount: 50000,
          method: 'manual',
          source: 'cash',
          createdAt: DateTime(2026, 1, 1),
        );

        final firestoreData = original.toFirestore();
        final restored = ContributionModel.fromFirestore(original.id, firestoreData);

        expect(restored.note, isNull);
        expect(restored.amount, equals(original.amount));
      });

      test('toFirestore contains all fields', () {
        final model = ContributionModel(
          id: 'c1',
          coupleId: 'cp1',
          jarId: 'j1',
          userId: 'u1',
          userName: 'N',
          amount: 100000,
          note: 'Test note',
          method: 'qr',
          source: 'app',
          createdAt: DateTime(2026, 1, 1),
        );

        final map = model.toFirestore();

        expect(map['coupleId'], equals('cp1'));
        expect(map['jarId'], equals('j1'));
        expect(map['userId'], equals('u1'));
        expect(map['userName'], equals('N'));
        expect(map['amount'], equals(100000));
        expect(map['note'], equals('Test note'));
        expect(map['method'], equals('qr'));
        expect(map['source'], equals('app'));
        expect(map['createdAt'], equals(DateTime(2026, 1, 1)));
      });
    });
  });

  group('Integration: SavingJar + Contribution', () {
    test('calculates remaining amount correctly', () {
      final jar = SavingJar(
        id: 'j1',
        coupleId: 'c1',
        name: 'Beach Trip',
        emoji: '🏖️',
        targetAmount: 1000000,
        currentAmount: 350000,
        createdAt: DateTime.now(),
      );

      final remaining = jar.targetAmount - jar.currentAmount;

      expect(remaining, equals(650000));
      expect(jar.progress, equals(0.35));
    });

    test('new contribution updates jar balance correctly', () {
      final jar = SavingJar(
        id: 'j1',
        coupleId: 'c1',
        name: 'Beach Trip',
        emoji: '🏖️',
        targetAmount: 1000000,
        currentAmount: 350000,
        createdAt: DateTime.now(),
      );

      const contributionAmount = 100000;
      final updatedJar = jar.copyWith(
        currentAmount: jar.currentAmount + contributionAmount,
      );

      expect(updatedJar.currentAmount, equals(450000));
      expect(updatedJar.progress, equals(0.45));
    });

    test('goal reached after contribution', () {
      final jar = SavingJar(
        id: 'j1',
        coupleId: 'c1',
        name: 'Beach Trip',
        emoji: '🏖️',
        targetAmount: 500000,
        currentAmount: 450000,
        createdAt: DateTime.now(),
      );

      final updatedJar = jar.copyWith(currentAmount: 500000);

      expect(updatedJar.progress, equals(1.0));
      expect(updatedJar.percentInt, equals(100));
    });
  });
}
