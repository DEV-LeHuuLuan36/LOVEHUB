import '../../domain/entities/ai_chat_message.dart';
import '../../domain/entities/ai_conversation.dart';
import '../../domain/entities/ai_usage.dart';
import '../../domain/entities/couple_ai_context.dart';

/// Outcome of a [AiChatRepository.sendQuestion] call. On success, the AI
/// reply text is returned. On failure, the [failureMessage] explains why
/// (limit hit, network error, AI error, etc.).
class AiChatSendOutcome {
  const AiChatSendOutcome._({this.reply, this.usage, this.failureMessage});
  factory AiChatSendOutcome.success({required String reply, required AiUsage usage}) =>
      AiChatSendOutcome._(reply: reply, usage: usage);
  factory AiChatSendOutcome.failure(String message, {AiUsage? usage}) =>
      AiChatSendOutcome._(failureMessage: message, usage: usage);

  final String? reply;
  final AiUsage? usage;
  final String? failureMessage;

  bool get isSuccess => reply != null;
}

abstract class AiChatRepository {
  /// Stream of all conversations for a couple, newest updatedAt first.
  Stream<List<AiConversation>> watchConversations(String coupleId);

  /// Stream of one conversation's metadata (null if deleted).
  Stream<AiConversation?> watchConversation(
    String coupleId,
    String conversationId,
  );

  /// Stream of all messages in a conversation, oldest first.
  Stream<List<AiChatMessage>> watchMessages(
    String coupleId,
    String conversationId,
  );

  /// Stream of today's usage counter for the couple (shared across all
  /// conversations).
  Stream<AiUsage?> watchUsage(String coupleId);

  /// Create a new empty conversation and return its id.
  Future<String> createConversation(String coupleId);

  /// Delete a conversation and all its messages.
  Future<void> deleteConversation(
    String coupleId,
    String conversationId,
  );

  /// Full send pipeline: limit check, auto-title on first message, persist
  /// user message, call Groq with the last [maxHistory] messages of THIS
  /// conversation, persist the assistant reply, bump the conversation's
  /// `updatedAt` + `lastMessagePreview`. When [localeCode] is set (e.g.
  /// "en" or "vi"), the system prompt asks the AI to reply in that
  /// language.
  Future<AiChatSendOutcome> sendQuestion({
    required String coupleId,
    required String conversationId,
    required String text,
    required String senderUid,
    required CoupleAiContext context,
    int maxHistory = 10,
    String? localeCode,
  });
}
