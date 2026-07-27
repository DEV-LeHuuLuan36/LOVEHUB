import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// SharedPreferences keys used to cache data for the background task.
/// The WorkManager isolate has NO access to Firebase or Riverpod, so all
/// background computation relies exclusively on these persisted values.
abstract class BackgroundCache {
  BackgroundCache._();

  static const String startDateMillis = 'cached_start_millis';
  static const String names = 'cached_names';
  static const String notifEnabled = 'notif_enabled';
  static const String wmRegistered = 'wm_registered';
}

/// The unique name of the periodic WorkManager task.
const backgroundTaskName = 'lovehub-refresh';

/// Top-level entry point for the WorkManager background isolate.
/// MUST be a top-level function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await _backgroundRefresh();
    } catch (_) {}
    return Future.value(true);
  });
}

/// Background refresh logic — runs in the WorkManager isolate with no Firebase/Riverpod access.
Future<void> _backgroundRefresh() async {
  final prefs = await SharedPreferences.getInstance();

  final startMillis = prefs.getInt(BackgroundCache.startDateMillis);
  if (startMillis == null) return;

  final names = prefs.getString(BackgroundCache.names) ?? '';
  final notifEnabled = prefs.getBool(BackgroundCache.notifEnabled) ?? false;
  final days = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(startMillis),
  ).inDays;

  // Update the home-screen widget via HomeWidget method channel.
  await _updateHomeWidget(days: days, names: names);

  // Persist notification data so the flutter_foreground_task foreground
  // TaskHandler can pick it up on its next tick.
  if (notifEnabled) {
    await prefs.setInt('com.pravera.flutter_foreground_task.prefs.days', days);
    await prefs.setString('com.pravera.flutter_foreground_task.prefs.names', names);
  }
}

/// Calls the HomeWidget method channel to update the widget text fields.
Future<void> _updateHomeWidget({required int days, required String names}) async {
  const channel = MethodChannel('home_widget');

  await channel.invokeMethod('saveWidgetData', {'id': 'days', 'data': '$days'});
  await channel.invokeMethod('saveWidgetData', {'id': 'names', 'data': names});
  await channel.invokeMethod('saveWidgetData', {
    'id': 'updatedAt',
    'data': DateTime.now().toIso8601String(),
  });
  await channel.invokeMethod('updateWidget', {
    'android': 'LoveWidgetProvider',
    'qualifiedAndroidName': 'com.example.lovehub.LoveWidgetProvider',
  });
}

/// Foreground-side service: caches data and manages WorkManager lifecycle.
class BackgroundRefreshService {
  BackgroundRefreshService._();

  /// Persist startDate + names + notifEnabled to SharedPreferences so the
  /// background task can compute the day count without Firebase.
  static Future<void> cacheForBackground({
    required DateTime startDate,
    required String names,
    required bool notifEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt(BackgroundCache.startDateMillis, startDate.millisecondsSinceEpoch),
      prefs.setString(BackgroundCache.names, names),
      prefs.setBool(BackgroundCache.notifEnabled, notifEnabled),
    ]);
  }

  /// Register the periodic refresh task (once). Uses ExistingWorkPolicy.keep
  /// so calling this on every home load is safe — it won't duplicate tasks.
  static Future<void> registerPeriodicTask() async {
    final prefs = await SharedPreferences.getInstance();
    final already = prefs.getBool(BackgroundCache.wmRegistered) ?? false;
    if (already) return;

    await Workmanager().registerPeriodicTask(
      backgroundTaskName,
      backgroundTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );

    await prefs.setBool(BackgroundCache.wmRegistered, true);
  }

  /// Cancel the periodic task and clear the registration flag.
  /// Call this on sign-out.
  static Future<void> cancelPeriodicTask() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      Workmanager().cancelByUniqueName(backgroundTaskName),
      prefs.setBool(BackgroundCache.wmRegistered, false),
    ]);
  }
}
