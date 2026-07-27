import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../config/api_config.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/couple_ai_context.dart';

/// Provider-agnostic AI data source. Currently backed by Groq's
/// OpenAI-compatible chat completions API. The single entry point is
/// [coachReply], which both the chat thread and any future flows use.
abstract class GeminiDataSource {
  Future<String> coachReply({
    required List<ChatMessage> history,
    required CoupleAiContext context,
    String? localeCode,
  });
}

/// Thrown by the datasource when the upstream AI call fails. The
/// repository layer reads [statusCode] and [body] for friendly messaging.
class AiHttpException implements Exception {
  AiHttpException({
    required this.statusCode,
    required this.body,
    this.model,
  });

  final int statusCode;
  final String body;
  final String? model;

  @override
  String toString() =>
      'AiHttpException(status=${statusCode}, model=$model, body=$body)';
}

class GeminiDataSourceImpl implements GeminiDataSource {
  GeminiDataSourceImpl({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  /// Model fallback chain. Order matters: the first model that returns 200
  /// wins. 404/400 (model error) → try next. 401/403 (key) → STOP and
  /// surface. 429 → STOP (rate limit).
  static const List<String> candidateModels = <String>[
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
    'llama3-70b-8192',
    'openai/gpt-oss-20b',
  ];

  /// Top of every system message. Tells the model the data is precomputed
  /// (no need to recalculate dates) and that the AI cannot perform actions
  /// yet. Replies in the user's app language when [localeCode] is given.
  static String _systemIdentity(String? localeCode) {
    final lang = switch (localeCode) {
      'vi' => 'Vietnamese (Tiếng Việt)',
      'en' => 'English',
      _ => 'English',
    };
    return "You are LoveHub's couple assistant. Trust the precomputed numbers "
        "(don't recalculate dates). Answer warmly and concisely in $lang. "
        'You can suggest date ideas/plans when asked, but you cannot perform '
        'actions yet.';
  }

  /// Build the full system message by joining the identity preamble, the
  /// precomputed context text, and a separator so the model sees clear
  /// sections.
  String _buildSystemMessage(CoupleAiContext context, String? localeCode) {
    final ctxText = context.contextText;
    final block = StringBuffer()
      ..writeln(_systemIdentity(localeCode))
      ..writeln()
      ..writeln('---')
      ..writeln()
      ..writeln(ctxText);
    return block.toString().trimRight();
  }

  /// Build the OpenAI-style messages array for a chat. The system preamble
  /// is the first message; then the chat history maps:
  ///   [ChatMessage.user] -> role: "user"
  ///   [ChatMessage.ai]   -> role: "assistant"
  /// (OpenAI uses "assistant", not "model".)
  List<Map<String, String>> _chatMessages(
    List<ChatMessage> history,
    String systemPreamble,
  ) {
    final out = <Map<String, String>>[
      {'role': 'system', 'content': systemPreamble},
    ];
    for (final msg in history) {
      if (msg.text.trim().isEmpty) continue;
      out.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text,
      });
    }
    return out;
  }

  /// Try each candidate model in order:
  ///   * 200         → parse `choices[0].message.content`, return.
  ///   * 404 / 400   → try next model (model error / unknown model name).
  ///   * 401 / 403   → STOP, throw [AiHttpException] (key/permission).
  ///   * 429         → STOP, throw [AiHttpException] (rate limit).
  ///   * other       → STOP, throw.
  ///   * transport   → propagate.
  Future<({String text, String model})> _tryModels(
    String tag,
    List<Map<String, String>> messages,
  ) async {
    final apiKey = ApiConfig.groqApiKey;
    debugPrint('AI_ERR: [$tag] candidateModels = $candidateModels');
    debugPrint('AI_ERR: [$tag] apiKey.prefix = '
        '${apiKey.length >= 4 ? apiKey.substring(0, 4) : "(too short)"}');
    debugPrint('AI_ERR: [$tag] apiKey.length = ${apiKey.length}');
    debugPrint('AI_ERR: [$tag] messages.length = ${messages.length}');
    debugPrint('AI_ERR: [$tag] endpoint = $_endpoint');

    AiHttpException? lastModelErr;
    for (final model in candidateModels) {
      debugPrint('AI_ERR: [$tag] trying model = $model');
      final body = <String, dynamic>{
        'model': model,
        'messages': messages,
        'temperature': 0.7,
      };

      final http.Response resp;
      try {
        resp = await _client.post(
          Uri.parse(_endpoint),
          headers: <String, String>{
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );
      } catch (e, st) {
        debugPrint('AI_ERR: [$tag] transport error on $model: ${e.runtimeType}: $e');
        debugPrint('AI_ERR: [$tag] stack = $st');
        rethrow;
      }

      final status = resp.statusCode;
      final raw = resp.body;
      final bodyPreview =
          raw.length > 2000 ? '${raw.substring(0, 2000)}...(truncated)' : raw;
      debugPrint('AI_ERR: [$tag] model=$model status=$status');
      debugPrint('AI_ERR: [$tag] model=$model body=$bodyPreview');

      if (status == 200) {
        final text = _extractText(raw, tag, model);
        // ignore: avoid_print
        debugPrint('AI_OK model=$model textLength=${text.length}');
        return (text: text, model: model);
      }

      if (status == 404 || status == 400) {
        // Model error / unknown model name — try the next one.
        debugPrint('AI_ERR: [$tag] model=$model status=$status (model error) — trying next');
        lastModelErr = AiHttpException(
          statusCode: status,
          body: raw,
          model: model,
        );
        continue;
      }

      if (status == 401 || status == 403) {
        // Key / permission — won't fix itself with another model.
        debugPrint('AI_ERR: status=$status body=$bodyPreview');
        throw AiHttpException(
          statusCode: status,
          body: raw,
          model: model,
        );
      }

      if (status == 429) {
        // Rate limit — surface immediately so the repository can show a
        // friendly rate-limit message.
        debugPrint('AI_ERR: status=$status body=$bodyPreview');
        throw AiHttpException(
          statusCode: status,
          body: raw,
          model: model,
        );
      }

      // Other non-2xx — don't loop, surface immediately.
      throw AiHttpException(
        statusCode: status,
        body: raw,
        model: model,
      );
    }

    throw lastModelErr ?? AiHttpException(
      statusCode: 404,
      body: 'all candidate models returned 404',
      model: null,
    );
  }

  /// Parse `choices[0].message.content` from a 200 body. Throws
  /// [AiHttpException] with a synthetic 502 if the payload is malformed.
  String _extractText(String raw, String tag, String model) {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      throw AiHttpException(
        statusCode: 502,
        body: 'Non-JSON 200 body: $raw',
        model: model,
      );
    }

    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      debugPrint('AI_ERR: [$tag] model=$model no choices in 200 response');
      throw AiHttpException(
        statusCode: 502,
        body: 'No choices in response',
        model: model,
      );
    }
    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>?;
    final finish = first['finish_reason'];
    if (message == null) {
      debugPrint('AI_ERR: [$tag] model=$model choice missing message. finish_reason=$finish');
      throw AiHttpException(
        statusCode: 502,
        body: 'Choice missing message (finish_reason=$finish)',
        model: model,
      );
    }
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      debugPrint('AI_ERR: [$tag] model=$model message.content is null/empty. finish_reason=$finish');
      throw AiHttpException(
        statusCode: 502,
        body: 'Message content is null/empty (finish_reason=$finish)',
        model: model,
      );
    }
    return content.trim();
  }

  @override
  Future<String> coachReply({
    required List<ChatMessage> history,
    required CoupleAiContext context,
    String? localeCode,
  }) async {
    if (history.isEmpty) {
      throw const FormatException('coachReply: history is empty');
    }
    ChatMessage? lastUser;
    for (final m in history) {
      if (m.isUser && m.text.trim().isNotEmpty) lastUser = m;
    }
    if (lastUser == null) {
      throw const FormatException('coachReply: no user message in history');
    }

    final system = _buildSystemMessage(context, localeCode);
    final messages = _chatMessages(history, system);
    final result = await _tryModels('chat', messages);
    return result.text;
  }
}
