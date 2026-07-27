import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/chat_message.dart';
import '../entities/couple_ai_context.dart';
import '../repositories/ai_repository.dart';

class CoachReplyUseCase {
  CoachReplyUseCase(this._repository);
  final AIRepository _repository;

  Future<Either<Failure, String>> call({
    required List<ChatMessage> history,
    required CoupleAiContext context,
  }) {
    return _repository.coachReply(history: history, context: context);
  }
}
