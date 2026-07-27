import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/background_refresh_service.dart';
import '../../../../services/checkin_reminder_service.dart';
import '../../../../services/foreground_notification_service.dart';
import '../../../../services/local_reminder_service.dart';
import '../../../couple/presentation/providers/couple_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Persisted toggle state for the love counter notification.
final loveCounterNotificationEnabledProvider =
    StateNotifierProvider<_ToggleNotifier, bool>((ref) {
  return _ToggleNotifier();
});

class _ToggleNotifier extends StateNotifier<bool> {
  _ToggleNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      state = prefs.getBool('love_counter_notification') ?? false;
    }
  }

  Future<void> set(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('love_counter_notification', value);
    if (mounted) state = value;
  }
}

/// Provider that constructs the names string from auth + partner profile.
final _notificationNamesProvider = Provider<String>((ref) {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final partner = ref.watch(partnerProfileProvider).valueOrNull;
  final yourName = authUser?.displayName ?? '';
  final partnerName = partner?.displayName ?? '';
  if (yourName.isNotEmpty && partnerName.isNotEmpty) {
    return '$yourName & $partnerName';
  }
  return yourName.isNotEmpty ? yourName : partnerName;
});

/// Watches loveDuration and pushes updates to the foreground notification
/// whenever the day count changes — but only when the toggle is ON.
final loveCounterNotificationUpdaterProvider = Provider<void>((ref) {
  // Watch all dependencies so this provider re-runs when any of them changes
  final notifEnabled = ref.watch(loveCounterNotificationEnabledProvider);
  if (!notifEnabled) return;

  final duration = ref.watch(loveDurationProvider);
  if (duration == null) return;

  final names = ref.watch(_notificationNamesProvider);

  // This callback runs on every rebuild triggered by any watched provider
  ForegroundNotificationService.update(days: duration.days, names: names);
});

/// Watches loveDuration and caches startDate + names + notifEnabled to
/// SharedPreferences so the WorkManager background task can compute days
/// without Firebase access.
final loveCounterBackgroundCacheProvider = Provider<void>((ref) {
  final notifEnabled = ref.watch(loveCounterNotificationEnabledProvider);

  final coupleId = ref.watch(currentCoupleIdProvider);
  if (coupleId == null) return;

  final coupleAsync = ref.watch(watchCoupleProvider(coupleId));
  final couple = coupleAsync.valueOrNull;
  final startDate = couple?.startDate;
  if (startDate == null) return;

  final names = ref.watch(_notificationNamesProvider);

  // Write to SharedPreferences for background access
  BackgroundRefreshService.cacheForBackground(
    startDate: startDate,
    names: names,
    notifEnabled: notifEnabled,
  );
});

/// Persisted toggle for the "Daily check-in" local notification.
/// When set true, schedules a 9:00 PM daily reminder via
/// [CheckinReminderService] (which uses flutter_local_notifications +
/// timezone). When set false, cancels it. State is persisted in
/// SharedPreferences so it survives restarts and reinstalls, and is
/// re-scheduled on app launch by [_restoreCheckinReminder] in main.dart.
final checkinReminderEnabledProvider =
    StateNotifierProvider<_CheckinReminderNotifier, bool>((ref) {
  return _CheckinReminderNotifier();
});

class _CheckinReminderNotifier extends StateNotifier<bool> {
  _CheckinReminderNotifier() : super(false) {
    _load();
  }

  static const _prefsKey = 'checkin_reminder_enabled';

  /// Awaitable handle for "the notifier has finished reading from
  /// SharedPreferences". Main code awaits this on cold start so the
  /// restore path doesn't race with the constructor's async load.
  final Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final value = prefs.getBool(_prefsKey) ?? false;
    state = value;
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Enable or disable the daily check-in reminder. Persists to
  /// SharedPreferences, then schedules or cancels the actual local
  /// notification. Returns true on success, false on permission denied
  /// (the toggle is rolled back to its previous value in that case).
  Future<bool> set(bool value) async {
    final previous = state;

    if (value) {
      // Make sure the plugin is initialized (no-op if already).
      await CheckinReminderService.init();
      final granted = await CheckinReminderService.requestPermission();
      if (!granted) {
        // Roll back so UI matches reality.
        if (mounted) state = previous;
        return false;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
    if (!mounted) return previous;
    state = value;

    if (value) {
      await CheckinReminderService.scheduleDaily();
    } else {
      await CheckinReminderService.cancel();
    }
    return true;
  }
}

/// Persisted toggle for the "Daily mood" local notification.
/// When set true, schedules a 9:00 PM daily reminder (id 1002) via
/// [LocalReminderService] (which uses flutter_local_notifications +
/// timezone). When set false, cancels it. State is persisted in
/// SharedPreferences so it survives restarts and reinstalls, and is
/// re-scheduled on app launch by [_restoreMoodReminder] in main.dart.
final moodReminderEnabledProvider =
    StateNotifierProvider<_MoodReminderNotifier, bool>((ref) {
  return _MoodReminderNotifier();
});

class _MoodReminderNotifier extends StateNotifier<bool> {
  _MoodReminderNotifier() : super(false) {
    _load();
  }

  static const _prefsKey = 'mood_reminder_enabled';

  /// Awaitable handle for "the notifier has finished reading from
  /// SharedPreferences". Main code awaits this on cold start so the
  /// restore path doesn't race with the constructor's async load.
  final Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final value = prefs.getBool(_prefsKey) ?? false;
    state = value;
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Enable or disable the daily mood reminder. Persists to
  /// SharedPreferences, then schedules or cancels the actual local
  /// notification. Returns true on success, false on permission denied
  /// (the toggle is rolled back to its previous value in that case).
  Future<bool> set(bool value) async {
    final previous = state;

    if (value) {
      // Make sure the plugin is initialized (no-op if already).
      await CheckinReminderService.init();
      final granted = await CheckinReminderService.requestPermission();
      if (!granted) {
        // Roll back so UI matches reality.
        if (mounted) state = previous;
        return false;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
    if (!mounted) return previous;
    state = value;

    if (value) {
      await LocalReminderService.schedule(spec: LocalReminders.dailyMood);
    } else {
      await LocalReminderService.cancel(LocalReminders.dailyMood.id);
    }
    return true;
  }
}
