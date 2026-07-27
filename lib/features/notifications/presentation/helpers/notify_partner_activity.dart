import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../providers/onesignal_providers.dart';
import '../providers/partner_activity_provider.dart';
import '../../domain/entities/notification_item.dart';
import '../../../../services/local_notification_inbox_service.dart';

/// Fire-and-forget helper for "Partner Activity" pushes.
///
/// Reads the persisted `partnerActivityEnabled` toggle and skips
/// silently if it's OFF. The push itself is best-effort and
/// cannot crash the triggering action — the underlying
/// [PartnerPushService] swallows all errors.
///
/// Centralizing this here keeps the four trigger sites
/// (check-in, mood, memory, pet feed) identical in behavior and
/// makes the toggle a single point of control.
Future<void> notifyPartnerActivity(
  WidgetRef ref, {
  required String title,
  required String message,
  Map<String, dynamic>? data,
}) async {
  // Gate: respect the user's "Partner Activity" toggle. The
  // notifier's default state is `true`, so the very first call on
  // a cold start still goes through even if the SharedPreferences
  // read hasn't completed yet.
  final enabled = ref.read(partnerActivityEnabledProvider);
  if (!enabled) {
    debugPrint('PARTNERPUSH: skipped (toggle OFF) — title="$title"');
    return;
  }

  final me = ref.read(authStateProvider).valueOrNull;
  final partner = ref.read(partnerProfileProvider).valueOrNull;
  if (me == null || partner == null) {
    debugPrint(
      'PARTNERPUSH: skipped (no user/partner) — title="$title", '
      'me=${me?.uid}, partner=${partner?.uid}',
    );
    return;
  }

  final service = ref.read(partnerPushServiceProvider);
  // Deliberately not awaited so the caller's UI doesn't block on
  // the network round-trip. Failures are swallowed inside the
  // service.
  unawaited(
    service.sendToPartner(
      partnerUid: partner.uid,
      title: title,
      message: message,
      data: data,
    ),
  );

  // Also record in the sender's local inbox
  LocalNotificationInboxService.appendNotification(
    title: title,
    body: message,
    type: NotificationItemType.partnerCheckin,
  );
}
