import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One configured daily local notification. Each toggle in
/// `NotificationSettingsScreen` is backed by one of these.
class LocalReminderSpec {
  const LocalReminderSpec({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  /// Stable id used by `flutter_local_notifications` for the
  /// scheduled notification. Used to cancel / re-schedule.
  final int id;

  /// Notification title (e.g. "Daily check-in 💕").
  final String title;

  /// Notification body.
  final String body;

  /// Payload string passed to `onDidReceiveNotificationResponse`.
  /// Used by the app to route on tap.
  final String payload;
}

/// Canonical reminder specs used by the app. All ids are stable so
/// they can be re-scheduled deterministically.
class LocalReminders {
  LocalReminders._();

  static const LocalReminderSpec dailyCheckin = LocalReminderSpec(
    id: 1001,
    title: 'Daily check-in 💕',
    body: "Don't forget to check in with your partner today!",
    payload: 'checkin_reminder',
  );

  static const LocalReminderSpec dailyMood = LocalReminderSpec(
    id: 1002,
    title: 'Mood check 😊',
    body: 'How are you feeling today? Set your mood.',
    payload: 'mood_reminder',
  );
}

/// Shared service for daily local notifications.
///
/// `flutter_local_notifications` is configured once (channel +
/// permissions) and then reused for every reminder. Each reminder
/// has a stable id, title, body and payload (see [LocalReminders]).
/// State persistence and toggle UI are handled by Riverpod
/// providers in `notification_providers.dart`; this class only deals
/// with the OS side of things.
class LocalReminderService {
  LocalReminderService._();

  static const String _channelId = 'reminders';
  static const String _channelName = 'Reminders';
  static const String _channelDescription =
      'Daily reminders for you and your partner.';

  static bool _initialized = false;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Optional callback registered in [init] for when the user taps
  /// a notification. The service passes the notification's `payload`
  /// (e.g. `checkin_reminder`, `mood_reminder`).
  static void Function(String? payload)? _onSelect;

  /// Initialize the plugin. Safe to call multiple times.
  ///
  /// [onSelect] is invoked when the user taps any of our
  /// notifications. We use it to route inside the app
  /// (e.g. `mood_reminder` → open Mood screen).
  static Future<void> init({
    void Function(String? payload)? onSelect,
  }) async {
    _onSelect = onSelect;
    if (_initialized) return;

    // Timezone setup — required for zonedSchedule. The actual local
    // zone is resolved lazily inside _nextFireTime using the device's
    // current offset (Etc/GMT family).
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _onSelect?.call(response.payload);
      },
    );

    _initialized = true;
  }

  /// Returns true if the user has granted POST_NOTIFICATIONS permission.
  /// On platforms that don't require runtime permission, returns true.
  static Future<bool> hasPermission() async {
    if (!_initialized) await init();
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) return true;
    return await impl.areNotificationsEnabled() ?? false;
  }

  /// Request the runtime POST_NOTIFICATIONS permission (Android 13+).
  /// Returns true if granted.
  static Future<bool> requestPermission() async {
    if (!_initialized) await init();
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) return true;
    return await impl.requestNotificationsPermission() ?? false;
  }

  /// Schedule a daily-repeating reminder for [spec]. Cancels any
  /// previously-scheduled notification with the same id, then
  /// re-schedules for the next [hour]:[minute] in the device's local
  /// time, repeating daily via
  /// `matchDateTimeComponents: DateTimeComponents.time`.
  static Future<void> schedule({
    required LocalReminderSpec spec,
    int hour = 21,
    int minute = 0,
  }) async {
    if (!_initialized) await init();

    await _plugin.cancel(spec.id);

    final fireAt = _nextFireTime(hour: hour, minute: minute);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );
    const details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.zonedSchedule(
        spec.id,
        spec.title,
        spec.body,
        fireAt,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: spec.payload,
      );
    } catch (e, st) {
      // Don't crash the app on permission denied / no exact-alarm.
      // The toggle will just not appear as scheduled.
      if (kDebugMode) {
        debugPrint(
          '[LocalReminderService] schedule(${spec.id}) failed: $e\n$st',
        );
      }
    }
  }

  /// Cancel a specific reminder.
  static Future<void> cancel(int id) async {
    if (!_initialized) await init();
    await _plugin.cancel(id);
  }

  /// True if the reminder with the given [id] is currently scheduled.
  static Future<bool> isScheduled(int id) async {
    if (!_initialized) await init();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.any((p) => p.id == id);
  }

  /// The next `hour`:`minute` at or after the current time, in the
  /// device's effective local time. Used as the first-fire time for
  /// `zonedSchedule`; the plugin will then repeat it daily via
  /// `matchDateTimeComponents: time`.
  ///
  /// We don't pull in a separate native-timezone package; instead we
  /// build a virtual zone whose current offset matches the device's
  /// reported offset. DST transitions within the same day are rare
  /// for an evening reminder, and the offset is re-evaluated on
  /// every cold start, which is the same compromise other apps make.
  static tz.TZDateTime _nextFireTime({
    required int hour,
    required int minute,
  }) {
    final location = _ensureLocalLocation();
    final now = tz.TZDateTime.now(location);
    var fire = tz.TZDateTime(
        location, now.year, now.month, now.day, hour, minute);
    if (!fire.isAfter(now)) {
      fire = fire.add(const Duration(days: 1));
    }
    return fire;
  }

  /// Returns a `tz.Location` whose current offset matches the device's
  /// `DateTime.timeZoneOffset`. Falls back to UTC if construction
  /// fails.
  static tz.Location _ensureLocalLocation() {
    final offset = DateTime.now().timeZoneOffset.inMinutes;
    // POSIX-style: Etc/GMT sign is reversed. UTC+7 → Etc/GMT-7.
    final sign = offset >= 0 ? '-' : '+';
    final abs = offset.abs();
    final posixName = 'Etc/GMT$sign${abs ~/ 60}';
    try {
      return tz.getLocation(posixName);
    } catch (_) {
      return tz.getLocation('UTC');
    }
  }
}
