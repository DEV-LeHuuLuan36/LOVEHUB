# LoveHub Firestore Security Rules — Deployment Guide

## Quick Deploy

```bash
# 1. Install Firebase CLI if not already
npm install -g firebase-tools

# 2. Login
firebase login

# 3. Set project
firebase use lovehub-app  # or your Firebase project ID

# 4. Deploy Firestore rules ONLY (no data loss)
firebase deploy --only firestore:rules
```

## Pre-deployment Checklist

- [ ] Review `firestore.rules` sections:
  - [ ] `hasIntegrity()` — verify Cloud Function `verifyIntegrityToken` is deployed
  - [ ] `coupleId` immutability after first write
  - [ ] `aiUsage/{coupleId}` — `allow write: if false` (server-only)
- [ ] Run simulator tests (requires Firebase emulator):
  ```bash
  firebase emulators:exec --only firestore \
    "dart run test/security/firestore_rules_integration_test.dart"
  ```
- [ ] Backup current rules:
  ```bash
  firebase firestore:rules:get > firestore.rules.backup.$(date +%Y%m%d)
  ```

## Rollback Plan

If rules break production:

```bash
# Restore from backup
firebase deploy --only firestore:rules \
  --token "$(cat ~/.config/firebase/refresh_token)"
```

## Rule Changes History

| Date       | Version | Change Summary                    |
|------------|---------|-----------------------------------|
| 2026-07-18 | v2      | Added integrity gate + timestamp  |
| (older)    | v1      | Initial rules from project start  |

## Performance Note

Rules with `get()` calls (e.g. `hasIntegrity()`) cost reads.
The `integrityVerdict` check calls `get()` twice per write.
Monitor Firestore reads in Firebase Console → Usage.

For high-traffic couples (1000+ writes/day), consider caching
the verdict in a dedicated subcollection with a shorter TTL.
