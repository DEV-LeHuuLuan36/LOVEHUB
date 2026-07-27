import 'local_reminder_service.dart';

/// Thin wrapper around [LocalReminderService] for the "Daily check-in"
/// reminder. Kept for source-compatibility with the existing
/// `notification_providers.dart` and `main.dart` call sites.
///
/// New reminders (e.g. Mood) should be added to [LocalReminders] and
/// consumed directly via [LocalReminderService]; no need to add a
/// dedicated wrapper class.
class CheckinReminderService {
  CheckinReminderService._();

  /// Stable id for the daily check-in notification. Mirrors
  /// [LocalReminders.dailyCheckin] so callers that reference the id
  /// directly (e.g. `pendingNotificationRequests`) still work.
  static const int dailyCheckinId = 1001;

  static const _spec = LocalReminders.dailyCheckin;

  /// Initialize the underlying plugin. Safe to call multiple times.
  /// [onSelect] is invoked when the user taps a notification.
  static Future<void> init({void Function(String? payload)? onSelect}) {
    return LocalReminderService.init(onSelect: onSelect);
  }

  /// Returns true if the user has granted POST_NOTIFICATIONS permission.
  static Future<bool> hasPermission() =>
      LocalReminderService.hasPermission();

  /// Request the runtime POST_NOTIFICATIONS permission (Android 13+).
  static Future<bool> requestPermission() =>
      LocalReminderService.requestPermission();

  /// Schedule the daily check-in reminder at 9:00 PM local time.
  static Future<void> scheduleDaily({int hour = 21, int minute = 0}) {
    return LocalReminderService.schedule(
      spec: _spec,
      hour: hour,
      minute: minute,
    );
  }

  /// Cancel the daily check-in reminder (if any).
  static Future<void> cancel() => LocalReminderService.cancel(dailyCheckinId);

  /// True if the daily reminder is currently scheduled.
  static Future<bool> isScheduled() =>
      LocalReminderService.isScheduled(dailyCheckinId);
}
