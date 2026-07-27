import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../domain/repositories/onesignal_repository.dart';
import '../services/onesignal_service.dart';

/// Repository implementation that wires the OneSignal SDK to the
/// app's data layer.
///
/// Responsibilities:
///   * delegate SDK calls to [OneSignalService];
///   * mirror the OneSignal push subscription id ("player id")
///     onto the user's Firestore doc as `oneSignalPlayerId` so the
///     server (Cloudflare Worker) can target them.
///
/// The `oneSignalPlayerId` write is best-effort: we don't want a
/// transient Firestore error to break the rest of the auth flow.
class OneSignalRepositoryImpl implements OneSignalRepository {
  OneSignalRepositoryImpl({
    required OneSignalService service,
    required FirebaseFirestore firestore,
  })  : _service = service,
        _firestore = firestore;

  final OneSignalService _service;
  final FirebaseFirestore _firestore;

  /// Uid currently "logged in" to OneSignal (== firebase auth uid).
  /// Tracked so we know where to write the player id when the
  /// subscription changes.
  String? _loggedInUid;

  @override
  Future<void> init() async {
    _service.init();
  }

  @override
  Future<void> loginUser(String uid) async {
    _loggedInUid = uid;
    await _service.loginUser(uid);
    // After login, the subscription may be re-assigned to this
    // external id. Push the current player id to Firestore right
    // away (the observer below will handle future changes).
    final id = _service.currentSubscriptionId;
    if (id != null) {
      await _writePlayerId(uid, id);
    }
  }

  @override
  Future<void> logout() async {
    final uid = _loggedInUid;
    _loggedInUid = null;
    // Clear the player id on the user's doc so the server no
    // longer targets them. Best-effort: don't await failures.
    if (uid != null) {
      try {
        await _firestore.doc(FirestorePaths.user(uid)).set(
          {'oneSignalPlayerId': FieldValue.delete()},
          SetOptions(merge: true),
        );
      } catch (_) {}
    }
    await _service.logout();
  }

  @override
  String? get currentSubscriptionId => _service.currentSubscriptionId;

  @override
  Future<bool> requestPermission() => _service.requestPermission();

  @override
  void onSubscriptionChanged(void Function(String id) callback) {
    _service.onSubscriptionChanged((id) {
      callback(id);
      // Mirror to Firestore for the currently-logged-in user.
      final uid = _loggedInUid;
      if (uid != null) {
        // Fire-and-forget: the doc write is best-effort.
        _writePlayerId(uid, id);
      }
    });
  }

  Future<void> _writePlayerId(String uid, String id) async {
    try {
      await _firestore.doc(FirestorePaths.user(uid)).set(
        {'oneSignalPlayerId': id},
        SetOptions(merge: true),
      );
    } catch (_) {
      // Swallow — the next subscription change will retry.
    }
  }
}
