import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted toggle for "Partner Activity" pushes (the OneSignal
/// push sent to the partner when the user does something —
/// check-in, mood, memory, pet feed).
///
/// Default: **ON**. New users start opted-in; the toggle is the
/// way to mute partner pushes without losing the local reminders.
final partnerActivityEnabledProvider =
    StateNotifierProvider<PartnerActivityNotifier, bool>((ref) {
  return PartnerActivityNotifier();
});

class PartnerActivityNotifier extends StateNotifier<bool> {
  PartnerActivityNotifier() : super(true) {
    _load();
  }

  static const _prefsKey = 'partnerActivityEnabled';

  /// Awaitable handle for "the notifier has finished reading from
  /// SharedPreferences". Cold-start code that wants the *real*
  /// persisted value (rather than the default-`true` in-memory
  /// fallback) can `await ready` once.
  final Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final value = prefs.getBool(_prefsKey) ?? true;
    state = value;
    if (!_ready.isCompleted) _ready.complete();
  }

  Future<void> set(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
    if (mounted) state = value;
  }
}
