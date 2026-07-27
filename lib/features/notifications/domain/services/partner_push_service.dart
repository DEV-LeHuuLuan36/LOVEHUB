/// Domain interface for sending a "Partner Activity" push.
///
/// The actual transport (HTTP, gRPC, smoke signals) is an
/// implementation detail; the rest of the app only depends on this
/// interface. Implementations live in `data/`.
abstract class PartnerPushService {
  /// Send a push to the partner (the user paired with the
  /// currently-signed-in user, identified by their Firebase uid —
  /// the same value we register as OneSignal's `external_id`).
  ///
  /// Fire-and-forget: the caller awaits the returned future so it
  /// can sequence work, but failures must never crash the user's
  /// triggering action. Implementations must catch all errors and
  /// log them; they should not rethrow.
  ///
  /// [data] is an arbitrary JSON-friendly map that is forwarded to
  /// the Worker; the Worker attaches it as `additionalData` on the
  /// OneSignal push (used to route inside the app on tap).
  Future<void> sendToPartner({
    required String partnerUid,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  });
}
