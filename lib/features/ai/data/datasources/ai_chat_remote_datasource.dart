import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/entities/ai_conversation.dart';
import '../../domain/entities/ai_usage.dart';
import '../models/ai_chat_message_model.dart';
import '../models/ai_conversation_model.dart';

/// Result of a `consumeQuestion` call. Either the user is allowed to send
/// (and the new usage is reported), or the limit was hit and we surface a
/// friendly reason.
class AiUsageResult {
  const AiUsageResult._({required this.allowed, required this.usage, this.reason});
  factory AiUsageResult.allowed(AiUsage usage) =>
      AiUsageResult._(allowed: true, usage: usage);
  factory AiUsageResult.denied(AiUsage usage, String reason) =>
      AiUsageResult._(allowed: false, usage: usage, reason: reason);

  final bool allowed;
  final AiUsage usage;
  final String? reason;
}

/// Firestore-backed datasource for the shared AI chat. Conversations live
/// under `aiChats/{coupleId}/conversations/{conversationId}` with their
/// messages nested under `…/messages/{messageId}`. The daily counter lives
/// at `aiUsage/{coupleId}`.
abstract class AiChatRemoteDataSource {
  /// Stream of conversations, ordered by `updatedAt` descending (most
  /// recently updated first).
  Stream<List<AiConversation>> watchConversations(String coupleId);

  /// Stream of one conversation's metadata (or null if deleted).
  Stream<AiConversation?> watchConversation(
    String coupleId,
    String conversationId,
  );

  /// Stream of all messages in a conversation, ordered by `createdAt`
  /// ascending.
  Stream<List<AiChatMessage>> watchMessages(
    String coupleId,
    String conversationId,
  );

  /// Stream of the current day's usage doc. Emits `null` when no doc
  /// exists yet for the couple.
  Stream<AiUsage?> watchUsage(String coupleId);

  /// Atomically: reset the counter if `date != today`, then check the
  /// 20/day limit. If allowed, increment and return [AiUsageResult.allowed].
  /// Otherwise return [AiUsageResult.denied] with [reason] set.
  ///
  /// This MUST be called BEFORE writing the user message and before calling
  /// the AI, so a denied request never produces a Firestore write.
  Future<AiUsageResult> consumeQuestion(String coupleId);

  /// Create a new empty conversation and return its id.
  Future<String> createConversation(String coupleId);

  /// Delete a conversation and (best-effort batched) all its messages.
  Future<void> deleteConversation(
    String coupleId,
    String conversationId,
  );

  /// Update a conversation's `updatedAt` and `lastMessagePreview` (and
  /// optionally its `title`) to reflect a new message.
  Future<void> touchConversation({
    required String coupleId,
    required String conversationId,
    required String preview,
    String? title,
  });

  /// Append a user message to a conversation. Returns the generated doc id.
  Future<String> addUserMessage({
    required String coupleId,
    required String conversationId,
    required String text,
    required String senderUid,
  });

  /// Append an assistant message to a conversation. Returns the generated
  /// doc id.
  Future<String> addAssistantMessage({
    required String coupleId,
    required String conversationId,
    required String text,
  });
}

class AiChatRemoteDataSourceImpl implements AiChatRemoteDataSource {
  AiChatRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _conversationsCol(String coupleId) =>
      _firestore.collection(FirestorePaths.aiConversations(coupleId));

  DocumentReference<Map<String, dynamic>> _conversationDoc(
    String coupleId,
    String conversationId,
  ) =>
      _conversationsCol(coupleId).doc(conversationId);

  CollectionReference<Map<String, dynamic>> _messagesCol(
    String coupleId,
    String conversationId,
  ) =>
      _firestore.collection(
        FirestorePaths.aiConversationMessages(coupleId, conversationId),
      );

  /// Reference to the couple's daily-usage document:
  /// `aiUsage/{coupleId}`. The doc path is a 2-segment string of the
  /// form `aiUsage/{coupleId}`, so it must be built with
  /// `collection('aiUsage').doc(coupleId)` — NOT
  /// `collection('aiUsage/$coupleId')`, which would interpret that
  /// 2-segment string as a single collection name and throw
  /// "A collection path must point to a valid collection".
  DocumentReference<Map<String, dynamic>> _usageDoc(String coupleId) =>
      _firestore.collection('aiUsage').doc(coupleId);

  /// `yyyy-MM-dd` for [now] in the device's local time zone. The whole
  /// app's day boundary uses the same convention.
  String _todayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  /// Dump every useful field of a thrown object with the AILIMIT_ERR
  /// prefix. Specifically extracts FirebaseException fields when present.
  void _logLimitError(String where, Object e, StackTrace st) {
    // ignore: avoid_print
    debugPrint('AILIMIT_ERR: [$where] started');
    // ignore: avoid_print
    debugPrint('AILIMIT_ERR: [$where] type     = ${e.runtimeType}');
    // ignore: avoid_print
    debugPrint('AILIMIT_ERR: [$where] toString = $e');

    // Pull the well-known Firestore fields when this is a FirebaseException
    // (it usually is — permission-denied / not-found / unavailable).
    final dyn = e as dynamic;
    try {
      // ignore: avoid_print
      debugPrint('AILIMIT_ERR: [$where] code     = ${dyn.code}');
    } catch (_) {/* not a FirebaseException */}
    try {
      // ignore: avoid_print
      debugPrint('AILIMIT_ERR: [$where] message  = ${dyn.message}');
    } catch (_) {}
    try {
      // ignore: avoid_print
      debugPrint('AILIMIT_ERR: [$where] plugin   = ${dyn.plugin}');
    } catch (_) {}
    try {
      final details = dyn.details as Object?;
      if (details != null) {
        // ignore: avoid_print
        debugPrint('AILIMIT_ERR: [$where] details  = $details');
      }
    } catch (_) {}
    try {
      final stackMsg = dyn.stackTrace;
      if (stackMsg != null) {
        // ignore: avoid_print
        debugPrint('AILIMIT_ERR: [$where] innerStack = $stackMsg');
      }
    } catch (_) {}

    // ignore: avoid_print
    debugPrint('AILIMIT_ERR: [$where] stack    = $st');
  }

  @override
  Stream<List<AiConversation>> watchConversations(String coupleId) {
    return _conversationsCol(coupleId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => AiConversationModel.fromFirestore(d.id, d.data()),
              )
              .toList(growable: false),
        );
  }

  @override
  Stream<AiConversation?> watchConversation(
    String coupleId,
    String conversationId,
  ) {
    return _conversationDoc(coupleId, conversationId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AiConversationModel.fromFirestore(snap.id, snap.data()!);
    });
  }

  @override
  Stream<List<AiChatMessage>> watchMessages(
    String coupleId,
    String conversationId,
  ) {
    return _messagesCol(coupleId, conversationId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => AiChatMessageModel.fromFirestore(d.id, d.data()),
              )
              .toList(growable: false),
        );
  }

  @override
  Stream<AiUsage?> watchUsage(String coupleId) {
    final today = _todayKey();
    return _usageDoc(coupleId).snapshots().map((snap) {
      if (!snap.exists) return null;
      // BUG FIX: fromMap now checks stored.date against today. If the doc
      // holds yesterday's date, fromMap returns AiUsage(date:today, count:0)
      // so the "X/20 hôm nay" banner shows 0 instead of yesterday's stale
      // count.  The write side (consumeQuestion) already handles the reset
      // atomically inside the transaction — this makes the read side consistent.
      return AiUsage.fromMap(snap.data(), today: today);
    });
  }

  @override
  Future<AiUsageResult> consumeQuestion(String coupleId) async {
    final docRef = _usageDoc(coupleId);
    final docPath = docRef.path;
    final today = _todayKey();

    // ── INPUT AUDIT ─────────────────────────────────────────────────────
    // Surface what we're about to touch *before* any network call so
    // "Could not check your daily limit" errors can be diagnosed from the
    // logs alone.
    // ignore: avoid_print
    debugPrint('AILIMIT: consumeQuestion input '
        // ignore: unnecessary_null_comparison
        'coupleId.isNull=${coupleId == null} '
        'coupleId.isEmpty=${coupleId.isEmpty} '
        'coupleId="$coupleId" '
        'docPath="$docPath" '
        'today="$today"');

    try {
      return await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final stored = AiUsage.fromMap(snap.data());
        final isStale = stored == null || stored.date != today;
        final current =
            isStale ? AiUsage(date: today, count: 0) : stored;

        if (current.isAtLimit) {
          // Persist a reset for the new day, in case we crossed midnight
          // during the wait. No-op if already fresh.
          if (isStale) {
            tx.set(docRef, {'date': today, 'count': 0});
          }
          // ignore: avoid_print
          debugPrint(
            'AILIMIT_ERR: coupleId=$coupleId hit limit count=${current.count}/'
            '${AiUsage.dailyLimit} date=${current.date}',
          );
          return AiUsageResult.denied(
            current,
            'Daily AI limit reached (${AiUsage.dailyLimit}/day). Try again tomorrow.',
          );
        }

        final next = AiUsage(date: today, count: current.count + 1);
        tx.set(docRef, {'date': next.date, 'count': next.count});
        // ignore: avoid_print
        debugPrint(
          'AILIMIT_OK: coupleId=$coupleId count=${next.count}/'
          '${AiUsage.dailyLimit} date=${next.date}',
        );
        return AiUsageResult.allowed(next);
      });
    } catch (e, st) {
      _logLimitError('consumeQuestion', e, st);
      rethrow;
    }
  }

  @override
  Future<String> createConversation(String coupleId) async {
    final now = DateTime.now();
    final model = AiConversationModel(
      id: '',
      title: 'New chat',
      createdAt: now,
      updatedAt: now,
      lastMessagePreview: '',
    );
    final ref = await _conversationsCol(coupleId).add(model.toFirestore());
    return ref.id;
  }

  @override
  Future<String> addUserMessage({
    required String coupleId,
    required String conversationId,
    required String text,
    required String senderUid,
  }) async {
    final model = AiChatMessageModel(
      id: '',
      role: 'user',
      text: text,
      createdAt: DateTime.now(),
      senderUid: senderUid,
    );
    final ref = await _messagesCol(coupleId, conversationId)
        .add(model.toFirestore());
    return ref.id;
  }

  @override
  Future<String> addAssistantMessage({
    required String coupleId,
    required String conversationId,
    required String text,
  }) async {
    final model = AiChatMessageModel(
      id: '',
      role: 'assistant',
      text: text,
      createdAt: DateTime.now(),
    );
    final ref = await _messagesCol(coupleId, conversationId)
        .add(model.toFirestore());
    return ref.id;
  }

  @override
  Future<void> touchConversation({
    required String coupleId,
    required String conversationId,
    required String preview,
    String? title,
  }) async {
    final update = <String, dynamic>{
      'updatedAt': DateTime.now(),
      'lastMessagePreview': preview,
    };
    if (title != null) update['title'] = title;
    await _conversationDoc(coupleId, conversationId).update(update);
  }

  @override
  Future<void> deleteConversation(
    String coupleId,
    String conversationId,
  ) async {
    // 1. Best-effort batched delete of all messages in the conversation.
    final msgs = _messagesCol(coupleId, conversationId);
    while (true) {
      final snap = await msgs.limit(500).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      try {
        await batch.commit();
      } catch (e, st) {
        debugPrint('AI_ERR: deleteConversation batch.commit failed: $e');
        debugPrint('AI_ERR: $st');
        rethrow;
      }
      if (snap.docs.length < 500) break;
    }

    // 2. Delete the conversation document itself.
    try {
      await _conversationDoc(coupleId, conversationId).delete();
    } catch (e, st) {
      debugPrint('AI_ERR: deleteConversation doc.delete failed: $e');
      debugPrint('AI_ERR: $st');
      rethrow;
    }
  }
}
