---
description: Firebase Firestore, RTDB, FCM patterns cho LoveHub
globs: lib/**/*repository*.dart, lib/**/*service*.dart, functions/**/*.js
alwaysApply: false
---

# Firebase Patterns — LoveHub

## Firestore Paths (chuẩn, không thay đổi)
```
couples/{coupleId}
users/{userId}
streaks/{coupleId}
checkins/{coupleId}/{date}/{userId}
pets/{coupleId}
diaries/{coupleId}/entries/{entryId}
moods/{coupleId}/daily/{date}/{userId}
savingJars/{coupleId}/jars/{jarId}
transactions/{coupleId}/history/{txId}
```

## Offline Persistence (main.dart, chạy 1 lần)
```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

## Real-time Listener Pattern
```dart
@riverpod
Stream<PetEntity> petStream(PetStreamRef ref) {
  final coupleId = ref.watch(coupleIdProvider);
  return FirebaseFirestore.instance
      .doc('pets/$coupleId')
      .snapshots()
      .map((doc) => PetEntity.fromFirestore(doc))
      .handleError((error) {
        debugPrint('Pet stream error: $error');
        throw const FirebaseFailure('Failed to load pet data');
      });
}
```

## Atomic Transaction (thú cưng HP, Love Points)
```dart
// LUÔN dùng transaction khi update số liệu mà 2 máy có thể cùng update
Future<void> feedPet(String coupleId, int lpCost) async {
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final petRef = FirebaseFirestore.instance.doc('pets/$coupleId');
    final snap = await tx.get(petRef);
    
    final currentHP = snap.data()!['hp'] as int;
    final currentLP = snap.data()!['lovePoints'] as int;
    
    if (currentLP < lpCost) throw Exception('Not enough Love Points');
    
    tx.update(petRef, {
      'hp': min(100, currentHP + 30),
      'lovePoints': currentLP - lpCost,
      'lastFed': FieldValue.serverTimestamp(),
    });
  });
}
```

## RTDB Presence (Online/Offline indicator)
```dart
// Chạy khi user login
void setupPresence(String userId, String coupleId) {
  final db = FirebaseDatabase.instance;
  final presenceRef = db.ref('presence/$coupleId/$userId');
  final connectedRef = db.ref('.info/connected');
  
  connectedRef.onValue.listen((event) {
    if (event.snapshot.value == true) {
      presenceRef.onDisconnect().set({
        'online': false, 
        'lastSeen': ServerValue.timestamp,
      });
      presenceRef.set({'online': true});
    }
  });
}
```

## Cloud Functions — Recovery Token (index.js)
```javascript
// Chạy mỗi Chủ nhật 23:59
exports.grantWeeklyRecoveryToken = onSchedule('59 23 * * 0', async (event) => {
  const MAX_TOKENS = 4;
  const db = admin.firestore();
  const couples = await db.collection('couples').get();
  
  const batch = db.batch();
  couples.forEach(doc => {
    const data = doc.data();
    const currentStreak = data.currentStreak || 0;
    const currentTokens = data.recoveryTokens || 0;
    
    // Chỉ grant token nếu streak >= 7 ngày và chưa đạt max
    if (currentStreak >= 7 && currentTokens < MAX_TOKENS) {
      batch.update(doc.ref, {
        recoveryTokens: Math.min(MAX_TOKENS, currentTokens + 1),
        lastTokenGranted: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
  
  await batch.commit();
  console.log(`Granted tokens to eligible couples`);
});
```

## Security Rules Quick Reference
```javascript
// Luôn check isCoupleember trước khi cho đọc/ghi
function isCoupleember(coupleId) {
  let couple = get(/databases/$(database)/documents/couples/$(coupleId));
  return request.auth.uid == couple.data.user1Id || 
         request.auth.uid == couple.data.user2Id;
}
```
