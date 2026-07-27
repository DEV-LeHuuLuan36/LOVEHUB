import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';

class WidgetService {
  WidgetService._();

  static const _androidName = 'LoveWidgetProvider';
  static const _qualifiedAndroidName = 'com.example.lovehub.LoveWidgetProvider';

  static Future<void> updateLoveWidget({
    required int days,
    required String names,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('days', '$days');
      await HomeWidget.saveWidgetData<String>('names', names);
      await HomeWidget.saveWidgetData<String>('updatedAt', DateTime.now().toIso8601String());
      await HomeWidget.updateWidget(
        androidName: _androidName,
        qualifiedAndroidName: _qualifiedAndroidName,
      );
    } catch (e) {
      debugPrint('[WidgetService] Failed to update widget: $e');
    }
  }
}
