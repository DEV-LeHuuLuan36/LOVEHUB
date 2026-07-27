import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/presence.dart';
import '../../domain/repositories/presence_repository.dart';

class PresenceRepositoryImpl implements PresenceRepository {
  PresenceRepositoryImpl() : _db = FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference _ref(String uid) => _db.ref('presence/$uid');

  @override
  Future<void> goOnline(String uid) async {
    // Wait for connection to be confirmed, then register onDisconnect BEFORE going online
    await _db.ref('.info/connected').onValue.firstWhere((event) {
      return event.snapshot.value == true;
    });

    final userRef = _ref(uid);

    // Register onDisconnect: when connection drops, set offline + lastSeen
    await userRef.onDisconnect().set({
      'isOnline': false,
      'lastSeen': ServerValue.timestamp,
    });

    // Go online
    await userRef.set({
      'isOnline': true,
      'lastSeen': ServerValue.timestamp,
    });
    debugPrint('[PresenceRepo] goOnline SET for uid=$uid (RTDB path: presence/$uid)');
  }

  @override
  Future<void> goOffline(String uid) async {
    await _ref(uid).set({
      'isOnline': false,
      'lastSeen': ServerValue.timestamp,
    });
    debugPrint('[PresenceRepo] goOffline SET for uid=$uid (RTDB path: presence/$uid)');
  }

  @override
  Stream<Presence> watchPresence(String uid) {
    return _ref(uid).onValue.map((event) {
      final snapshot = event.snapshot;
      final data = snapshot.value as Map<dynamic, dynamic>?;
      debugPrint('[PresenceRepo] watchPresence($uid) event: ${snapshot.value}');

      if (data == null) return Presence.offline;

      final isOnline = data['isOnline'] as bool? ?? false;
      DateTime? lastSeen;

      final ts = data['lastSeen'];
      if (ts != null) {
        if (ts is int) {
          lastSeen = DateTime.fromMillisecondsSinceEpoch(ts);
        }
      }

      return Presence(isOnline: isOnline, lastSeen: lastSeen);
    });
  }
}
