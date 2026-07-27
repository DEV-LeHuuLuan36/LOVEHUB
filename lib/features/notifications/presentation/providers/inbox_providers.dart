import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/local_notification_inbox_service.dart';
import '../../domain/entities/notification_item.dart';

// ─── State ────────────────────────────────────────────────────────────────────

@immutable
class NotificationInboxState {
  const NotificationInboxState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<NotificationItem> items;
  final bool isLoading;
  final String? error;

  int get unreadCount => items.where((item) => !item.isRead).length;
  bool get isEmpty => items.isEmpty && !isLoading;

  NotificationInboxState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return NotificationInboxState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class NotificationInboxNotifier extends StateNotifier<NotificationInboxState> {
  NotificationInboxNotifier() : super(const NotificationInboxState()) {
    _registerSyncCallback();
    load();
  }

  void _registerSyncCallback() {
    LocalNotificationInboxService.attachSyncCallback(_syncItem);
  }

  /// Called by the service's static callback when a notification is appended
  /// from outside the normal WidgetRef path (e.g. from main.dart callbacks).
  void _syncItem(NotificationItem item) {
    final updatedItems = [item, ...state.items];
    final trimmed = updatedItems.length > 50
        ? updatedItems.sublist(0, 50)
        : updatedItems;
    state = state.copyWith(items: trimmed);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await LocalNotificationInboxService.getAll();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> append({
    required String title,
    required String body,
    required NotificationItemType type,
  }) async {
    try {
      final item = await LocalNotificationInboxService.appendNotification(
        title: title,
        body: body,
        type: type,
      );
      // Already synced via callback; just guard against duplicates
      if (!state.items.any((i) => i.id == item.id)) {
        final updatedItems = [item, ...state.items];
        final trimmed = updatedItems.length > 50
            ? updatedItems.sublist(0, 50)
            : updatedItems;
        state = state.copyWith(items: trimmed);
      }
    } catch (e) {
      // Silently fail — non-critical
    }
  }

  Future<void> markAsRead(String id) async {
    await LocalNotificationInboxService.markAsRead(id);
    final updatedItems = state.items.map((item) {
      if (item.id == id) return item.copyWith(isRead: true);
      return item;
    }).toList();
    state = state.copyWith(items: updatedItems);
  }

  Future<void> markAllAsRead() async {
    await LocalNotificationInboxService.markAllAsRead();
    final updatedItems = state.items
        .map((item) => item.copyWith(isRead: true))
        .toList();
    state = state.copyWith(items: updatedItems);
  }

  Future<void> delete(String id) async {
    await LocalNotificationInboxService.delete(id);
    final updatedItems = state.items.where((item) => item.id != id).toList();
    state = state.copyWith(items: updatedItems);
  }

  Future<void> clearAll() async {
    await LocalNotificationInboxService.clearAll();
    state = state.copyWith(items: []);
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final notificationInboxProvider =
    StateNotifierProvider<NotificationInboxNotifier, NotificationInboxState>(
  (ref) => NotificationInboxNotifier(),
);

final notificationUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationInboxProvider).unreadCount;
});

/// Convenience helper to append a notification from anywhere in the app.
extension NotificationInboxHelpers on WidgetRef {
  void appendNotification({
    required String title,
    required String body,
    required NotificationItemType type,
  }) {
    read(notificationInboxProvider.notifier).append(
      title: title,
      body: body,
      type: type,
    );
  }
}
