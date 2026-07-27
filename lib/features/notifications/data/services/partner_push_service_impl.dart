import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../config/api_config.dart';
import '../../domain/services/partner_push_service.dart';

/// HTTP implementation of [PartnerPushService].
///
/// Talks to the Cloudflare Worker at [ApiConfig.pushWorkerUrl].
/// The Worker holds the OneSignal REST API key as a secret, looks up
/// the partner's player id by external_id (== partner Firebase uid),
/// and dispatches the push.
///
/// Failure handling: every error path is caught, logged with the
/// `PARTNERPUSH_ERR:` prefix, and swallowed. Push delivery is
/// best-effort — a failed push must never break the user's
/// triggering action (check-in, mood, memory, pet feed).
class PartnerPushServiceImpl implements PartnerPushService {
  PartnerPushServiceImpl({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<void> sendToPartner({
    required String partnerUid,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    final url = ApiConfig.pushWorkerUrl;
    final body = <String, dynamic>{
      'targetExternalId': partnerUid,
      'title': title,
      'message': message,
      'data': data ?? const <String, dynamic>{},
    };

    debugPrint(
      'PARTNERPUSH: → POST $url, partnerUid=$partnerUid, '
      'title="$title", messageLen=${message.length}',
    );

    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'PARTNERPUSH_ERR: non-2xx response — '
          'status=${response.statusCode}, body=${response.body}',
        );
        return;
      }
      debugPrint(
        'PARTNERPUSH: ok — status=${response.statusCode}, '
        'bodyLen=${response.body.length}',
      );
    } on TimeoutException catch (e) {
      debugPrint('PARTNERPUSH_ERR: timeout: $e');
    } on http.ClientException catch (e) {
      debugPrint('PARTNERPUSH_ERR: http client error: $e');
    } catch (e, st) {
      // Last-resort catch — never rethrow. A failed push must not
      // crash the calling action.
      debugPrint('PARTNERPUSH_ERR: unexpected: $e\n$st');
    }
  }
}
