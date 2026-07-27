import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/presence_repository_impl.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../domain/entities/presence.dart';
import '../../domain/repositories/presence_repository.dart';

// ─── Repository provider ───────────────────────────────────────────────────────
final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  return PresenceRepositoryImpl();
});

// ─── Partner ID ───────────────────────────────────────────────────────────────
/// Returns the other user's ID in the couple, or null if not in a couple
final partnerIdProvider = Provider<String?>((ref) {
  final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (currentUid == null) return null;

  final coupleId = ref.watch(currentCoupleIdProvider);
  if (coupleId == null) return null;

  final coupleAsync = ref.watch(watchCoupleProvider(coupleId));
  final couple = coupleAsync.valueOrNull;
  if (couple == null) return null;

  final partnerId = couple.user1Id == currentUid ? couple.user2Id : couple.user1Id;
  debugPrint('[Presence] partnerId resolved: $partnerId (currentUid: $currentUid)');
  return partnerId;
});

// ─── Partner presence ──────────────────────────────────────────────────────────
/// Stream of the partner's presence; auto-disposed when not watched
final partnerPresenceProvider = StreamProvider.autoDispose<Presence>((ref) {
  final partnerId = ref.watch(partnerIdProvider);
  if (partnerId == null) {
    debugPrint('[Presence] partnerPresenceProvider: no partnerId yet → offline');
    return Stream.value(Presence.offline);
  }
  debugPrint('[Presence] partnerPresenceProvider: watching presence for uid=$partnerId');
  return ref.watch(presenceRepositoryProvider).watchPresence(partnerId);
});

// ─── App-lifecycle presence manager ────────────────────────────────────────────
/// Widget that wraps the authenticated shell and keeps the current user's
/// presence in sync with the app lifecycle (online on resume, offline on pause).
///
/// Place this in the app shell after auth redirect, e.g. inside the router's
/// shell/redirect when the user is authenticated.
class PresenceLifecycleManager extends ConsumerStatefulWidget {
  const PresenceLifecycleManager({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PresenceLifecycleManager> createState() => _PresenceLifecycleManagerState();
}

class _PresenceLifecycleManagerState extends ConsumerState<PresenceLifecycleManager>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnline();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOffline();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnline();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _setOffline();
    }
  }

  Future<void> _setOnline() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    debugPrint('[Presence] goOnline(uid=$uid) called');
    try {
      await ref.read(presenceRepositoryProvider).goOnline(uid);
      debugPrint('[Presence] goOnline succeeded');
    } catch (e) {
      debugPrint('[Presence] goOnline FAILED: $e');
    }
  }

  Future<void> _setOffline() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    debugPrint('[Presence] goOffline(uid=$uid) called');
    try {
      await ref.read(presenceRepositoryProvider).goOffline(uid);
      debugPrint('[Presence] goOffline succeeded');
    } catch (e) {
      debugPrint('[Presence] goOffline FAILED: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
