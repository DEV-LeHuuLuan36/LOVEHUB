import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Tracks user-inactivity and broadcasts a single-shot `onTimeout`
/// event after the configured idle window.
///
/// Wrap the root MaterialApp with `SessionTimeoutScope` and pass the
/// durations when the user is in foreground vs background.
class SessionTimeoutScope extends StatefulWidget {
  const SessionTimeoutScope({
    super.key,
    required this.child,
    required this.onTimeout,
    this.foregroundDuration = const Duration(minutes: 10),
    this.backgroundDuration = const Duration(minutes: 30),
  });

  final Widget child;

  /// Called exactly once when the user has been idle for the
  /// configured duration. The host is expected to lock / sign out.
  final VoidCallback onTimeout;

  /// Idle threshold while the app is visible.
  final Duration foregroundDuration;

  /// Idle threshold while the app is in the background.
  final Duration backgroundDuration;

  /// Trigger re-arming from anywhere in the tree.
  static _SessionTimer _of(BuildContext context) {
    final state = context.findAncestorStateOfType<_SessionTimeoutScopeState>();
    assert(state != null, 'No SessionTimeoutScope found in widget tree');
    return state!._timer;
  }

  /// Public re-arm helper. Visible name stays short.
  static void armFromContext(BuildContext context, Duration duration) {
    _of(context).arm(duration);
  }

  @override
  State<SessionTimeoutScope> createState() => _SessionTimeoutScopeState();
}

class _SessionTimeoutScopeState extends State<SessionTimeoutScope>
    with WidgetsBindingObserver {
  late final _SessionTimer _timer = _SessionTimer(this);

  bool _disposed = false;
  bool _inBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer.arm(widget.foregroundDuration);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _inBackground = true;
      _timer.arm(widget.backgroundDuration);
    } else if (state == AppLifecycleState.resumed) {
      _inBackground = false;
      // Reset the foreground clock on return.
      _timer.arm(widget.foregroundDuration);
    }
  }

  void fireTimeout() {
    if (_disposed) return;
    _timer.cancel();
    widget.onTimeout();
  }

  /// Called by the timer when the user remains idle.
  void onTick() {
    if (_disposed) return;
    fireTimeout();
  }

  Duration get currentThreshold => _inBackground
      ? widget.backgroundDuration
      : widget.foregroundDuration;

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SessionTimer {
  _SessionTimer(this._scope);
  final _SessionTimeoutScopeState _scope;
  Timer? _t;

  void arm(Duration d) {
    _t?.cancel();
    if (d <= Duration.zero) {
      _scope.onTick();
      return;
    }
    _t = Timer(d, _scope.onTick);
    if (kDebugMode) {
      debugPrint('[SESSION] idle window armed: ${d.inSeconds}s');
    }
  }

  void cancel() {
    _t?.cancel();
    _t = null;
  }
}

/// Lightweight mixin / helper for widgets that want to refresh the
/// idle clock on user interaction. Attach to a ListView / Gesture
/// handler.
mixin KeepAliveMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_poke);
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _poke();
  }

  void _poke([Duration? _]) {
    if (!mounted) return;
    final ctx = context;
    if (ctx.findAncestorStateOfType<_SessionTimeoutScopeState>() != null) {
      SessionTimeoutScope._of(ctx).arm(Duration.zero); // re-arm
    }
  }
}

/// Convenience wrapper: tap → rearm idle clock. Useful as a wrapper
/// for whole screens in MaterialApp's `builder`.
class SessionKeepAliveBuilder extends StatelessWidget {
  const SessionKeepAliveBuilder({
    super.key,
    required this.child,
  });
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        final s = context.findAncestorStateOfType<_SessionTimeoutScopeState>();
        s?._timer.arm(s.currentThreshold);
      },
      child: child,
    );
  }
}
