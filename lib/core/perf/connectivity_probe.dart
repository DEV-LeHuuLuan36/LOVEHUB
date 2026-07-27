import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Network connectivity state with debouncing. Reports
/// `online` only after the link has been stable for at least
/// [stableFor] to avoid flapping when the radio hops between
/// cells.
class ConnectivityProbe {
  ConnectivityProbe._();
  static final ConnectivityProbe _instance = ConnectivityProbe._();
  static ConnectivityProbe get instance => _instance;

  final Connectivity _conn = Connectivity();
  bool _online = true;
  DateTime _lastTransitionAt = DateTime.now();
  static const Duration stableFor = Duration(seconds: 2);

  /// Stream that fires with `true` when the device transitions to
  /// online, `false` when it goes offline.
  Stream<bool> get onChange => _controller.stream;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool get isOnline => _online;

  /// Start observing connectivity. Idempotent.
  Future<void> start() async {
    final initial = await _conn.checkConnectivity();
    _online = _isOnline(initial);
    _conn.onConnectivityChanged.listen((res) {
      final newOnline = _isOnline(res);
      if (newOnline == _online) return;
      _lastTransitionAt = DateTime.now();
      // Wait for stability before announcing.
      Future.delayed(stableFor, () {
        if (DateTime.now().difference(_lastTransitionAt) >= stableFor) {
          _online = newOnline;
          _controller.add(newOnline);
        }
      });
    });
  }

  /// Force a check now (used by the offline-queue worker).
  Future<bool> probeNow() async {
    final res = await _conn.checkConnectivity();
    return _isOnline(res);
  }

  bool _isOnline(dynamic res) {
    if (res is List) {
      return res.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn);
    }
    if (res is ConnectivityResult) {
      return res == ConnectivityResult.wifi ||
          res == ConnectivityResult.mobile ||
          res == ConnectivityResult.ethernet ||
          res == ConnectivityResult.vpn;
    }
    return false;
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

/// In-memory queue of work that should be retried once the device
/// comes back online. Each entry carries a serialised JSON body
/// plus a `kind` tag the worker uses to dispatch.
class OfflineQueue {
  OfflineQueue._();
  static final OfflineQueue _instance = OfflineQueue._();
  static OfflineQueue get instance => _instance;

  final List<QueuedItem> _items = <QueuedItem>[];
  final StreamController<QueuedItem> _onEnqueue =
      StreamController<QueuedItem>.broadcast();

  /// Queue a payload to be sent later. The `send` callback is
  /// called once we are online; it should throw if the network
  /// call still fails (we re-queue on throw).
  void enqueue({
    required String kind,
    required Map<String, Object?> payload,
    required Future<void> Function(Map<String, Object?>) send,
  }) {
    final item = QueuedItem(kind, payload, send);
    _items.add(item);
    _onEnqueue.add(item);
  }

  int get pending => _items.length;

  /// Drain the queue. Safe to call multiple times.
  Future<void> drain() async {
    if (!await ConnectivityProbe.instance.probeNow()) return;
    final snapshot = List<QueuedItem>.from(_items);
    for (final item in snapshot) {
      try {
        await item.send(item.payload);
        _items.remove(item);
      } catch (_) {
        // Keep the item; we'll try again on the next online event.
      }
    }
  }

  Stream<QueuedItem> get onEnqueue => _onEnqueue.stream;

  Future<void> dispose() async {
    await _onEnqueue.close();
  }
}

class QueuedItem {
  QueuedItem(this.kind, this.payload, this.send);
  final String kind;
  final Map<String, Object?> payload;
  final Future<void> Function(Map<String, Object?>) send;
}