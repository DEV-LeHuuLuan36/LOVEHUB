import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/chat_message.dart';
import '../entities/couple_ai_context.dart';

abstract class AIRepository {
  /// Get an AI reply given the conversation [history] and couple [context].
  /// Used by both the coach flow and the new shared AI chat. When
  /// [localeCode] is set (e.g. "en" or "vi"), the system prompt asks
  /// the model to reply in that language.
  Future<Either<Failure, String>> coachReply({
    required List<ChatMessage> history,
    required CoupleAiContext context,
    String? localeCode,
  });
}
