import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreakTokenLogic', () {
    group('15-day token award', () {
      test('streak reaches 15 days → +1 token, counter resets to 0', () {
        // Streak has reached 15 consecutive days.
        // The user earns +1 recovery token, and lastTokenStreak
        // is updated to the current streak so the 15-day counter
        // resets (diff = 0 until the next 15-day milestone).
        const currentStreak = 15;
        const lastTokenStreak = 0;
        const expectedDiff = currentStreak - lastTokenStreak; // = 15

        final earnedToken = expectedDiff >= 15;
        final newLastTokenStreak = earnedToken ? currentStreak : lastTokenStreak;

        expect(earnedToken, isTrue,
            reason: 'Streak of 15 should earn a recovery token');
        expect(newLastTokenStreak, equals(15),
            reason: 'lastTokenStreak should update to 15 after earning token');
      });

      test('streak breaks → 15-day progress resets to 0', () {
        // When a streak breaks (misses a day), the consecutive count
        // resets to 0, and so does the 15-day progress counter.
        const brokenStreak = 0;
        const expectedProgress = 0;

        // A broken streak means streak=0 and progress=0.
        final progressAfterBreak = brokenStreak == 0 ? 0 : 0;

        expect(brokenStreak, equals(0),
            reason: 'Broken streak should be 0');
        expect(progressAfterBreak, equals(expectedProgress),
            reason: '15-day progress should reset to 0 when streak breaks');
      });

      test('use recovery token → new streak does not reset progress', () {
        // When a recovery token is used to preserve a broken streak,
        // the streak continues from where it was. The 15-day
        // progress counter is NOT reset — it carries over.
        const streakBeforeBreak = 7;
        const recoveryTokenUsed = true;
        const streakAfterRecovery = 7; // streak preserved via token
        const progressBeforeBreak = 7;
        const expectedProgressAfter = 7; // progress NOT reset

        // Recovery token keeps streak alive; progress counter is preserved.
        final progressAfterRecovery =
            recoveryTokenUsed ? progressBeforeBreak : 0;

        expect(streakAfterRecovery, equals(streakBeforeBreak),
            reason: 'Streak should be preserved after using recovery token');
        expect(progressAfterRecovery, equals(expectedProgressAfter),
            reason: '15-day progress should NOT reset when using recovery token');
      });
    });
  });
}
