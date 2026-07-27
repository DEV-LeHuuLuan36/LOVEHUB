import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart' as fft;
import 'package:shared_preferences/shared_preferences.dart';

/// Top-level entry point required by flutter_foreground_task.
/// Must be a top-level function so the VM can resolve it across isolates.
@pragma('vm:entry-point')
void startCallback() {
  fft.FlutterForegroundTask.setTaskHandler(_LoveCounterTaskHandler());
}

/// TaskHandler that receives counter updates from the main app and refreshes
/// the ongoing notification text.
class _LoveCounterTaskHandler extends fft.TaskHandler {
  String _title = 'LoveHub';
  String _text = 'You & Partner';

  @override
  Future<void> onStart(DateTime timestamp, fft.TaskStarter starter) async {
    await _loadAndUpdate();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final days = data['days'] as int?;
      final names = data['names'] as String? ?? '';
      _text = _buildText(days, names);
      fft.FlutterForegroundTask.updateService(
        notificationTitle: _title,
        notificationText: _text,
      );
    }
  }

  Future<void> _loadAndUpdate() async {
    try {
      final allData = await fft.FlutterForegroundTask.getAllData();
      final days = allData['days'] as int?;
      final names = allData['names'] as String? ?? '';
      _text = _buildText(days, names);
      fft.FlutterForegroundTask.updateService(
        notificationTitle: _title,
        notificationText: _text,
      );
    } catch (_) {}
  }

  String _buildText(int? days, String names) {
    if (days == null || days <= 0) {
      return names.isNotEmpty ? names : 'You & Partner';
    }
    return '$days days together${names.isNotEmpty ? ' · $names' : ''}';
  }
}

/// Service for managing the LoveHub persistent foreground notification.
class ForegroundNotificationService {
  ForegroundNotificationService._();

  static const _serviceId = 999;
  static bool _initialized = false;

  static Future<fft.NotificationPermission> checkPermission() async =>
      fft.FlutterForegroundTask.checkNotificationPermission();

  static Future<fft.NotificationPermission> requestPermission() async =>
      fft.FlutterForegroundTask.requestNotificationPermission();

  static Future<bool> requestIgnoreBatteryOptimization() async =>
      fft.FlutterForegroundTask.requestIgnoreBatteryOptimization();

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    fft.FlutterForegroundTask.init(
      androidNotificationOptions: fft.AndroidNotificationOptions(
        channelId: 'lovehub_counter',
        channelName: 'LoveHub',
        channelDescription: 'Shows your days together',
        channelImportance: fft.NotificationChannelImportance.LOW,
        priority: fft.NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showWhen: false,
        showBadge: false,
        onlyAlertOnce: true,
        visibility: fft.NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const fft.IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: fft.ForegroundTaskOptions(
        eventAction: fft.ForegroundTaskEventAction.nothing(),
        allowWakeLock: false,
      ),
    );
  }

  static Future<bool> start({required int days, required String names}) async {
    try {
      await _ensureInitialized();
      await _saveData(days: days, names: names);
      final text = _buildText(days, names);
      final result = await fft.FlutterForegroundTask.startService(
        serviceId: _serviceId,
        notificationTitle: 'LoveHub',
        notificationText: text,
        notificationInitialRoute: '/',
      );
      if (result is fft.ServiceRequestFailure) {
        debugPrint('[ForegroundNotif] start failed: ${result.error}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[ForegroundNotif] start error: $e');
      return false;
    }
  }

  static Future<void> update({required int days, required String names}) async {
    try {
      final isRunning = await fft.FlutterForegroundTask.isRunningService;
      if (!isRunning) return;
      await _saveData(days: days, names: names);
      final text = _buildText(days, names);
      await fft.FlutterForegroundTask.updateService(
        notificationTitle: 'LoveHub',
        notificationText: text,
      );
      fft.FlutterForegroundTask.sendDataToTask({'days': days, 'names': names});
    } catch (e) {
      debugPrint('[ForegroundNotif] update error: $e');
    }
  }

  static Future<void> stop() async {
    try {
      final isRunning = await fft.FlutterForegroundTask.isRunningService;
      if (!isRunning) return;
      await fft.FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('[ForegroundNotif] stop error: $e');
    }
  }

  static Future<void> restartIfNeeded({
    required int days,
    required String names,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('love_counter_notification') ?? false;
      if (!enabled) return;
      final isRunning = await fft.FlutterForegroundTask.isRunningService;
      if (isRunning) await stop();
      await start(days: days, names: names);
    } catch (e) {
      debugPrint('[ForegroundNotif] restartIfNeeded error: $e');
    }
  }

  static Future<void> _saveData({required int days, required String names}) async {
    await fft.FlutterForegroundTask.saveData(key: 'days', value: days);
    await fft.FlutterForegroundTask.saveData(key: 'names', value: names);
  }

  static String _buildText(int days, String names) {
    if (days <= 0) return names.isNotEmpty ? names : 'You & Partner';
    return '$days days together${names.isNotEmpty ? ' · $names' : ''}';
  }
}

