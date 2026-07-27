import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/couple_ai_context.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/gemini_data_source.dart';

class AIRepositoryImpl implements AIRepository {
  AIRepositoryImpl({required GeminiDataSource dataSource})
      : _dataSource = dataSource;

  final GeminiDataSource _dataSource;

  /// Log the FULL raw exception + stack so the real cause is visible in
  /// logcat / `flutter run` output. Never log the API key itself.
  void _logError(String where, Object error, StackTrace stack) {
    final lines = <String>[
      'AI_ERR: [$where]',
      '  type     = ${error.runtimeType}',
      '  toString = $error',
    ];
    if (error is AiHttpException) {
      lines.add('  status   = ${error.statusCode}');
      lines.add('  model    = ${error.model ?? "(none)"}');
      // Body may be long; cap at 4000 chars.
      final body = error.body;
      final capped = body.length > 4000
          ? '${body.substring(0, 4000)}...(truncated)'
          : body;
      lines.add('  body     = $capped');
    } else if (error is FormatException) {
      lines.add('  message  = ${error.message}');
    }
    lines.add('  stack    = $stack');
    for (final l in lines) {
      // ignore: avoid_print
      debugPrint(l);
    }
  }

  String _friendlyMessage(Object error) {
    if (error is AiHttpException) {
      final code = error.statusCode;
      final body = error.body.toLowerCase();
      if (code == 400) {
        if (body.contains('api key') ||
            body.contains('api_key') ||
            body.contains('credential') ||
            body.contains('authorization')) {
          return 'The AI service rejected the API key (HTTP 400). Please check ai_config.dart.';
        }
        return 'The AI request was rejected (HTTP 400). Check the model name and request format.';
      }
      if (code == 401 || code == 403) {
        return 'The AI service rejected the request (HTTP $code). The API key may be invalid or restricted.';
      }
      if (code == 404) {
        return 'The AI model was not found (HTTP 404). Tried all fallbacks — see AI_ERR logs.';
      }
      if (code == 429) {
        return 'AI is taking a quick breather (rate-limit). Try again in a moment.';
      }
      if (code >= 500) {
        return 'The AI service is temporarily unavailable (HTTP $code). Please try again.';
      }
      return 'AI request failed (HTTP $code). Please try again.';
    }
    if (error is FormatException) {
      return 'AI returned an empty response. Please try again.';
    }
    final raw = error.toString().toLowerCase();
    if (raw.contains('socket') || raw.contains('network') || raw.contains('timeout')) {
      return 'Network hiccup — please check your connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Future<Either<Failure, String>> coachReply({
    required List<ChatMessage> history,
    required CoupleAiContext context,
    String? localeCode,
  }) async {
    try {
      final text = await _dataSource.coachReply(
        history: history,
        context: context,
        localeCode: localeCode,
      );
      return Right(text);
    } catch (e, st) {
      _logError('coachReply', e, st);
      return Left(ServerFailure(_friendlyMessage(e)));
    }
  }
}
