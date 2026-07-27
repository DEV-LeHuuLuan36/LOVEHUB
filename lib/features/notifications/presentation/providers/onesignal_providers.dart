import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/onesignal_repository_impl.dart';
import '../../data/services/onesignal_service.dart';
import '../../data/services/partner_push_service_impl.dart';
import '../../domain/repositories/onesignal_repository.dart';
import '../../domain/services/partner_push_service.dart';

/// The OneSignal SDK wrapper singleton.
final oneSignalServiceProvider = Provider<OneSignalService>((ref) {
  return OneSignalService();
});

/// Domain repository used by the rest of the app. Wires the
/// service to FirebaseFirestore so the player id can be mirrored
/// onto the user doc.
final oneSignalRepositoryProvider = Provider<OneSignalRepository>((ref) {
  return OneSignalRepositoryImpl(
    service: ref.watch(oneSignalServiceProvider),
    firestore: ref.watch(_oneSignalFirestoreProvider),
  );
});

/// Sends a "Partner Activity" push via the Cloudflare Worker.
/// Used by the activity triggers (check-in, mood, memory, pet feed).
final partnerPushServiceProvider = Provider<PartnerPushService>((ref) {
  return PartnerPushServiceImpl();
});

/// Internal provider that pulls the existing `firestoreProvider` from
/// the auth feature so we don't depend on it directly.
final _oneSignalFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return ref.watch(firestoreProvider);
});
