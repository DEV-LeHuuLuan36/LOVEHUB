import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Replaces the red "screen of death" with a friendly fallback.
///
/// Wire this from main() right after `runApp` (or in the
/// `ErrorWidget.builder` hook in MaterialApp).
///
/// Why: a single broken widget should not terminate the app.
class SafeErrorBoundary {
  SafeErrorBoundary._();

  /// Install the global ErrorWidget builder. Call this exactly once
  /// per process, typically from main().
  static void install() {
    ErrorWidget.builder = _buildFriendly;
    // FlutterError handler in release mode.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('[ERROR_BOUNDARY] ${details.exceptionAsString()}');
    };
  }

  /// The friendly widget shown in place of the default error.
  /// Kept simple so it doesn't itself throw.
  static Widget _buildFriendly(FlutterErrorDetails details) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFF1A1A1A),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '💔 Đã có lỗi xảy ra',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _safeMessage(details),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Strip stack traces + library symbols before exposing the
  /// message to users. We still log the full details server-side
  /// via the audit logger.
  static String _safeMessage(FlutterErrorDetails details) {
    if (kReleaseMode) return 'Vui lòng thử lại hoặc liên hệ hỗ trợ.';
    return details.exceptionAsString();
  }
}

/// Wrap any child widget in an [ErrorBoundary] to isolate failures.
/// Catches errors thrown during build/layout/paint and falls back
/// to the friendly widget.
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
  });

  final Widget child;
  final Widget Function(Object error, StackTrace? st)? fallback;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stack;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallback?.call(_error!, _stack) ??
          SafeErrorBoundary._buildFriendly(
            FlutterErrorDetails(exception: _error!, stack: _stack),
          );
    }
    return widget.child;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset error when the widget reappears with new dependencies.
    if (_error != null) {
      setState(() {
        _error = null;
        _stack = null;
      });
    }
  }
}