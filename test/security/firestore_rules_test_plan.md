# Firestore Security Rules — Test Plan

These tests use `@firebase/rules-unit-testing` against the Firestore
emulator to verify that the production rules correctly allow / deny
operations. Run with:

```bash
firebase emulators:exec --only firestore \
  "dart run test/security/firestore_rules_integration_test.dart"
```

## Test matrix

| # | Test                                              | User     | Couple   | Expected |
|---|---------------------------------------------------|----------|----------|----------|
| 1 | Read own profile                                  | self     | —        | ✅        |
| 2 | Read other's profile when in same couple          | self     | A        | ✅        |
| 3 | Read other's profile when in different couple     | self     | B        | ❌        |
| 4 | Read other user (no couple)                       | other    | —        | ❌        |
| 5 | Read couple when member                           | self     | A        | ✅        |
| 6 | Read couple when not member                       | self     | B        | ❌        |
| 7 | Create couple with self as memberA                | self     | —        | ✅        |
| 8 | Create couple with another as memberA             | self     | —        | ❌        |
| 9 | Update couple anniversary                        | self     | A        | ✅        |
| 10| Update couple while not member                    | self     | B        | ❌        |
| 11| Read streaks/{ownCouple}                          | self     | A        | ✅        |
| 12| Read streaks/{otherCouple}                        | self     | B        | ❌        |
| 13| Write streak checkin with valid coupleId          | self     | A        | ✅        |
| 14| Write streak checkin with mismatched coupleId     | self     | A        | ❌        |
| 15| Write saving jar/contribution nested              | self     | A        | ✅        |
| 16| Increment aiUsage from client                     | self     | A        | ❌        |
| 17| Read linkCodes                                    | anonymous| —        | ❌        |
| 18| Read catch-all                                    | self     | —        | ❌        |
| 19| Integrity gate: write with stale verdict          | self     | A        | ❌        |
| 20| Integrity gate: write with verdict=EMULATOR       | self     | A        | ❌        |
| 21| Timestamp out of window (> 24 h old)              | self     | A        | ❌        |
| 22| CoupleId mutation on user doc                     | self     | A        | ❌        |
| 23| HP out of range (> 100)                           | self     | A        | ❌        |
| 24| LP negative                                       | self     | A        | ❌        |

## Implementation notes

The integration test (`firestore_rules_integration_test.dart`)
needs the Firebase emulator running. Until that test is wired,
the unit-test stubs under `test/security/` cover the key
properties deterministically:

- `attack_idor_test.dart` — confirms the rules list every
  couple-namespaced collection.
- `attack_replay_test.dart` — confirms the ReplayGuard contract.
- `attack_dos_test.dart` — confirms the in-app RateLimiter.
- `attack_pin_bypass_test.dart` — confirms the pin store covers
  every critical host and that `network_security_config.xml` is
  present + correct.
- `attack_input_fuzz_test.dart` — fuzzes InputValidator against
  known-bad inputs.
- `input_validator_test.dart` — happy-path coverage.