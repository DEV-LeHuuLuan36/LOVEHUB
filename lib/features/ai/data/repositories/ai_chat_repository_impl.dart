import 'package:flutter/foundation.dart';

// ignore: unused_import
import 'package:dartz/dartz.dart';

import '../../domain/entities/ai_chat_message.dart';
import '../../domain/entities/ai_conversation.dart';
import '../../domain/entities/ai_usage.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/couple_ai_context.dart';
import '../../domain/repositories/ai_chat_repository.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/ai_chat_remote_datasource.dart';

class AiChatRepositoryImpl implements AiChatRepository {
  AiChatRepositoryImpl({
    required AiChatRemoteDataSource remote,
    required AIRepository aiRepository,
  })  : _remote = remote,
        _aiRepository = aiRepository;

  final AiChatRemoteDataSource _remote;
  final AIRepository _aiRepository;

  @override
  Stream<List<AiConversation>> watchConversations(String coupleId) =>
      _remote.watchConversations(coupleId);

  @override
  Stream<AiConversation?> watchConversation(
    String coupleId,
    String conversationId,
  ) =>
      _remote.watchConversation(coupleId, conversationId);

  @override
  Stream<List<AiChatMessage>> watchMessages(
    String coupleId,
    String conversationId,
  ) =>
      _remote.watchMessages(coupleId, conversationId);

  @override
  Stream<AiUsage?> watchUsage(String coupleId) => _remote.watchUsage(coupleId);

  @override
  Future<String> createConversation(String coupleId) =>
      _remote.createConversation(coupleId);

  @override
  Future<void> deleteConversation(
    String coupleId,
    String conversationId,
  ) =>
      _remote.deleteConversation(coupleId, conversationId);

  @override
  Future<AiChatSendOutcome> sendQuestion({
    required String coupleId,
    required String conversationId,
    required String text,
    required String senderUid,
    required CoupleAiContext context,
    int maxHistory = 10,
    String? localeCode,
  }) async {
    // 1. Limit check (atomic in Firestore).
    final AiUsageResult result;
    try {
      result = await _remote.consumeQuestion(coupleId);
    } catch (e, st) {
      // Structured log so the real failure (permission-denied,
      // not-found, network, etc.) is visible in `flutter run` / logcat.
      // ignore: avoid_print
      debugPrint('AILIMIT_ERR: [sendQuestion.consume] started');
      // ignore: avoid_print
      debugPrint('AILIMIT_ERR: [sendQuestion.consume] '
          // ignore: unnecessary_null_comparison
          'coupleId.isNull=${coupleId == null} '
          'coupleId.isEmpty=${coupleId.isEmpty} '
          'coupleId="$coupleId" '
          'conversationId="$conversationId"');
      // ignore: avoid_print
      debugPrint('AILIMIT_ERR: [sendQuestion.consume] '
          'type=${e.runtimeType}');
      // ignore: avoid_print
      debugPrint('AILIMIT_ERR: [sendQuestion.consume] toString=$e');

      final dyn = e as dynamic;
      try {
        // ignore: avoid_print
        debugPrint(
            'AILIMIT_ERR: [sendQuestion.consume] code=${dyn.code}');
      } catch (_) {}
      try {
        // ignore: avoid_print
        debugPrint(
            'AILIMIT_ERR: [sendQuestion.consume] message=${dyn.message}');
      } catch (_) {}
      try {
        // ignore: avoid_print
        debugPrint(
            'AILIMIT_ERR: [sendQuestion.consume] plugin=${dyn.plugin}');
      } catch (_) {}
      try {
        final details = dyn.details as Object?;
        if (details != null) {
          // ignore: avoid_print
          debugPrint(
              'AILIMIT_ERR: [sendQuestion.consume] details=$details');
        }
      } catch (_) {}
      // ignore: avoid_print
      debugPrint('AILIMIT_ERR: [sendQuestion.consume] stack=$st');

      return AiChatSendOutcome.failure(
        'Could not check your daily limit. Please try again.',
      );
    }
    if (!result.allowed) {
      return AiChatSendOutcome.failure(
        result.reason ?? 'Daily AI limit reached. Try again tomorrow.',
        usage: result.usage,
      );
    }

    // 2. Snapshot the current message list so we can detect "this is the
    //    first user message" for auto-titling and so the AI sees the
    //    current state right before we write the new prompt.
    List<AiChatMessage> prior;
    try {
      prior = await _remote
          .watchMessages(coupleId, conversationId)
          .first
          .timeout(const Duration(seconds: 5));
    } catch (e, st) {
      debugPrint('AI_ERR: sendQuestion.fetchHistory failed: $e');
      debugPrint('AI_ERR: $st');
      return AiChatSendOutcome.failure(
        'Could not load chat history. Please try again.',
        usage: result.usage,
      );
    }

    final isFirstUserMessage =
        !prior.any((m) => m.isUser && m.text.trim().isNotEmpty);
    final newTitle =
        isFirstUserMessage ? _titleFromText(text) : null;

    // 3. Persist the user message.
    try {
      await _remote.addUserMessage(
        coupleId: coupleId,
        conversationId: conversationId,
        text: text,
        senderUid: senderUid,
      );
    } catch (e, st) {
      debugPrint('AI_ERR: sendQuestion.addUserMessage failed: $e');
      debugPrint('AI_ERR: $st');
      return AiChatSendOutcome.failure(
        'Could not save your message. Please try again.',
        usage: result.usage,
      );
    }

    // 4. Build the history to send to the AI: trim to the last
    //    [maxHistory] messages of THIS conversation (before the new
    //    write), then append the new user prompt.
    final trimmed = prior.length > maxHistory
        ? prior.sublist(prior.length - maxHistory)
        : prior;
    final history = <ChatMessage>[
      ...trimmed.map(
        (m) => ChatMessage(
          role: m.role == 'assistant' ? ChatRole.ai : ChatRole.user,
          text: m.text,
          timestamp: m.createdAt,
        ),
      ),
      ChatMessage(
        role: ChatRole.user,
        text: text,
        timestamp: DateTime.now(),
      ),
    ];

    // 5. Call Groq.
    final aiResult = await _aiRepository.coachReply(
      history: history,
      context: context,
      localeCode: localeCode,
    );

    return aiResult.fold(
      (failure) => AiChatSendOutcome.failure(
        failure.message,
        usage: result.usage,
      ),
      (reply) async {
        // 6a. Write the assistant reply.
        try {
          await _remote.addAssistantMessage(
            coupleId: coupleId,
            conversationId: conversationId,
            text: reply,
          );
        } catch (e, st) {
          debugPrint('AI_ERR: sendQuestion.addAssistantMessage failed: $e');
          debugPrint('AI_ERR: $st');
          return AiChatSendOutcome.failure(
            'Got a reply but could not save it. Please try again.',
            usage: result.usage,
          );
        }
        // 6b. Bump the conversation's updatedAt + lastMessagePreview
        //     (and set the title on the first message).
        try {
          await _remote.touchConversation(
            coupleId: coupleId,
            conversationId: conversationId,
            preview: _previewFromText(reply),
            title: newTitle,
          );
        } catch (e, st) {
          // Non-fatal: a stale preview doesn't break the chat.
          debugPrint('AI_ERR: sendQuestion.touchConversation failed: $e');
          debugPrint('AI_ERR: $st');
        }
        return AiChatSendOutcome.success(reply: reply, usage: result.usage);
      },
    );
  }

  /// Derive a short conversation title from the first user message.
  /// Newlines are collapsed, runs of whitespace are collapsed, and the
  /// result is truncated to ~40 chars with an ellipsis.
  static String _titleFromText(String text) {
    const max = 40;
    final cleaned = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'New chat';
    if (cleaned.length <= max) return cleaned;
    return '${cleaned.substring(0, max).trimRight()}…';
  }

  /// Derive a short preview from a message (first ~80 chars on a single
  /// line).
  static String _previewFromText(String text) {
    const max = 80;
    final cleaned = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length <= max) return cleaned;
    return '${cleaned.substring(0, max).trimRight()}…';
  }
}
