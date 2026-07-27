import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
// ignore_for_file: library_private_types_in_public_api
import '../features/notifications/domain/entities/notification_item.dart';

/// Callback type for syncing new notifications to the Riverpod state.
/// Registered via [LocalNotificationInboxService.attachSyncCallback].
typedef InboxSyncCallback = void Function(NotificationItem item);

class LocalNotificationInboxService {
  LocalNotificationInboxService._();

  static const String _storageKey = 'notification_inbox';
  static const int _maxItems = 50;

  static SharedPreferences? _prefs;

  static InboxSyncCallback? _syncCallback;

  /// Register a callback invoked whenever a notification is appended.
  /// Call once from main() after ProviderScope is established.
  static void attachSyncCallback(InboxSyncCallback cb) {
    _syncCallback = cb;
  }

  /// Appends a new notification item. Keeps only the most recent 50.
  /// Notifies the Riverpod state if a sync callback is registered.
  static Future<NotificationItem> appendNotification({
    required String title,
    required String body,
    required NotificationItemType type,
  }) async {
    final item = NotificationItem(
      id: const Uuid().v4(),
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      isRead: false,
    );

    final prefs = await _preferences;
    final items = await _loadItems(prefs);

    items.insert(0, item);

    final trimmed = items.length > _maxItems
        ? items.sublist(0, _maxItems)
        : items;

    await _saveItems(prefs, trimmed);

    // Sync to Riverpod state via callback (if registered)
    _syncCallback?.call(item);

    if (kDebugMode) {
      debugPrint('[LocalNotifInbox] appended: ${item.type.key} — "$title"');
    }

    return item;
  }

  /// Returns all items, newest first.
  static Future<List<NotificationItem>> getAll() async {
    final prefs = await _preferences;
    final items = await _loadItems(prefs);
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  /// Marks a single item as read by id.
  static Future<bool> markAsRead(String id) async {
    final prefs = await _preferences;
    final items = await _loadItems(prefs);
    var changed = false;
    final updated = items.map((item) {
      if (item.id == id && !item.isRead) {
        changed = true;
        return item.copyWith(isRead: true);
      }
      return item;
    }).toList();
    if (changed) await _saveItems(prefs, updated);
    return changed;
  }

  /// Marks all items as read.
  static Future<void> markAllAsRead() async {
    final prefs = await _preferences;
    final items = await _loadItems(prefs);
    final updated = items.map((item) => item.copyWith(isRead: true)).toList();
    await _saveItems(prefs, updated);
  }

  /// Deletes a single item by id.
  static Future<bool> delete(String id) async {
    final prefs = await _preferences;
    final items = await _loadItems(prefs);
    final lengthBefore = items.length;
    items.removeWhere((item) => item.id == id);
    if (items.length < lengthBefore) {
      await _saveItems(prefs, items);
      return true;
    }
    return false;
  }

  /// Clears all notification items.
  static Future<void> clearAll() async {
    final prefs = await _preferences;
    await prefs.remove(_storageKey);
  }

  /// Returns the count of unread notifications.
  static Future<int> unreadCount() async {
    final items = await getAll();
    return items.where((item) => !item.isRead).length;
  }

  // ─── Private helpers ──────────────────────────────────────────────────────────

  static Future<SharedPreferences> get _preferences async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<List<NotificationItem>> _loadItems(SharedPreferences prefs) async {
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[LocalNotifInbox] failed to decode items: $e\n$st');
      }
      return [];
    }
  }

  static Future<void> _saveItems(
    SharedPreferences prefs,
    List<NotificationItem> items,
  ) async {
    final jsonList = items.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, json.encode(jsonList));
  }
}
