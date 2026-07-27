import '../entities/presence.dart';

abstract class PresenceRepository {
  Future<void> goOnline(String uid);
  Future<void> goOffline(String uid);
  Stream<Presence> watchPresence(String uid);
}
