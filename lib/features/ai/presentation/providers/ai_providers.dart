import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/gemini_data_source.dart';
import '../../data/repositories/ai_repository_impl.dart';
import '../../domain/repositories/ai_repository.dart';
import '../../domain/usecases/coach_reply_usecase.dart';

// ─── Data source & repository ─────────────────────────────────────────────────
/// Provider-agnostic AI data source. Currently backed by Groq's
/// OpenAI-compatible chat completions API.
final geminiDataSourceProvider = Provider<GeminiDataSource>((ref) {
  return GeminiDataSourceImpl();
});

final aiRepositoryProvider = Provider<AIRepository>((ref) {
  return AIRepositoryImpl(dataSource: ref.watch(geminiDataSourceProvider));
});

// ─── Use case providers ──────────────────────────────────────────────────────
/// Generates a coach reply (used by the shared AI chat). Takes a short
/// conversation history (the chat repo trims to the last 10 messages)
/// plus the live couple context, and returns the AI's text reply.
final coachReplyUseCaseProvider = Provider<CoachReplyUseCase>((ref) {
  return CoachReplyUseCase(ref.watch(aiRepositoryProvider));
});
