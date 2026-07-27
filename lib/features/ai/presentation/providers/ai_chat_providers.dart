import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../data/datasources/ai_chat_remote_datasource.dart';
import '../../data/repositories/ai_chat_repository_impl.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/entities/ai_conversation.dart';
import '../../domain/entities/ai_usage.dart';
import '../../domain/entities/couple_ai_context.dart';
import '../../domain/repositories/ai_chat_repository.dart';
import 'ai_providers.dart';

// ─── Data source & repository ─────────────────────────────────────────────────
final aiChatRemoteDataSourceProvider =
    Provider<AiChatRemoteDataSource>((ref) {
  return AiChatRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

final aiChatRepositoryProvider = Provider<AiChatRepository>((ref) {
  return AiChatRepositoryImpl(
    remote: ref.watch(aiChatRemoteDataSourceProvider),
    aiRepository: ref.watch(aiRepositoryProvider),
  );
});

// ─── Stream providers (per coupleId / conversationId) ────────────────────────
/// Real-time stream of all conversations for a couple, newest
/// `updatedAt` first.
final watchAiConversationsProvider =
    StreamProvider.autoDispose.family<List<AiConversation>, String>(
        (ref, coupleId) {
  return ref.watch(aiChatRepositoryProvider).watchConversations(coupleId);
});

/// Real-time stream of one conversation's metadata (null after delete).
final watchAiConversationProvider = StreamProvider.autoDispose
    .family<AiConversation?, ({String coupleId, String conversationId})>(
  (ref, args) {
    return ref
        .watch(aiChatRepositoryProvider)
        .watchConversation(args.coupleId, args.conversationId);
  },
);

/// Real-time stream of messages in a conversation, ordered by `createdAt`
/// ascending.
final watchAiChatMessagesProvider = StreamProvider.autoDispose.family<
    List<AiChatMessage>, ({String coupleId, String conversationId})>(
  (ref, args) {
    return ref
        .watch(aiChatRepositoryProvider)
        .watchMessages(args.coupleId, args.conversationId);
  },
);

/// Real-time stream of the couple's daily AI usage counter (null if no
/// record yet for today). Shared across all conversations.
final watchAiChatUsageProvider =
    StreamProvider.autoDispose.family<AiUsage?, String>((ref, coupleId) {
  return ref.watch(aiChatRepositoryProvider).watchUsage(coupleId);
});

/// Convenience: latest usage for the *current* couple (or null when not
/// in a couple).
final currentAiChatUsageProvider = Provider<AiUsage?>((ref) {
  final coupleId = ref.watch(currentCoupleIdProvider);
  if (coupleId == null || coupleId.isEmpty) return null;
  return ref.watch(watchAiChatUsageProvider(coupleId)).valueOrNull;
});

// ─── Send controller ─────────────────────────────────────────────────────────
/// Holds the in-flight flag (and a transient error message) for the send
/// action. Real messages live in Firestore and stream back via
/// [watchAiChatMessagesProvider] — this controller only manages the action.
class AiChatSendState {
  const AiChatSendState({this.isSending = false, this.error});
  final bool isSending;
  final String? error;

  AiChatSendState copyWith({bool? isSending, String? error, bool clearError = false}) {
    return AiChatSendState(
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AiChatSendController extends StateNotifier<AiChatSendState> {
  AiChatSendController({
    required AiChatRepository repository,
    required String coupleId,
    required String conversationId,
  })  : _repository = repository,
        _coupleId = coupleId,
        _conversationId = conversationId,
        super(const AiChatSendState());

  final AiChatRepository _repository;
  final String _coupleId;
  final String _conversationId;

  Future<bool> send({
    required String text,
    required String senderUid,
    required CoupleAiContext context,
    String? localeCode,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (state.isSending) return false;

    state = state.copyWith(isSending: true, clearError: true);
    final outcome = await _repository.sendQuestion(
      coupleId: _coupleId,
      conversationId: _conversationId,
      text: trimmed,
      senderUid: senderUid,
      context: context,
      localeCode: localeCode,
    );
    if (!mounted) return false;
    if (outcome.isSuccess) {
      state = const AiChatSendState();
      return true;
    }
    state = AiChatSendState(isSending: false, error: outcome.failureMessage);
    return false;
  }
}

typedef _SendKey = ({String coupleId, String conversationId});

/// Send controller family keyed by `(coupleId, conversationId)`.
final aiChatSendControllerProvider = StateNotifierProvider.autoDispose
    .family<AiChatSendController, AiChatSendState, _SendKey>((ref, args) {
  return AiChatSendController(
    repository: ref.watch(aiChatRepositoryProvider),
    coupleId: args.coupleId,
    conversationId: args.conversationId,
  );
});
