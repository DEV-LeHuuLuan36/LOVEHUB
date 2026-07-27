import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for the persisted theme mode.
const String _kThemeModePrefsKey = 'theme_mode';

/// Persists the user's selected [ThemeMode] (system / light / dark)
/// across app launches.
///
/// State hydration is async — the first read of [themeModeProvider]
/// may briefly return [ThemeMode.system] until SharedPreferences has
/// been read. Callers should re-read after the first microtask to
/// get the persisted value.
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    // Defer hydration to next microtask. We must NOT block construction,
    // and we must NOT clobber any user-initiated setMode() call.
    _hydrated = false;
    Future.microtask(_load);
  }

  /// Becomes true after the first successful load from prefs OR after the
  /// first explicit setMode(). Used to guard against late-load races.
  bool _hydrated = false;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final raw = prefs.getString(_kThemeModePrefsKey);
    final mode = _decode(raw);
    // Only apply hydration result if the user hasn't already picked a mode
    // (i.e. setMode() was called before our prefs read completed).
    if (!_hydrated) {
      _hydrated = true;
      if (mode != state) {
        state = mode;
      }
    }
  }

  /// Update the theme mode and persist to SharedPreferences.
  Future<void> setMode(ThemeMode mode) async {
    _hydrated = true; // mark to suppress late hydration
    if (mode == state) return;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModePrefsKey, _encode(mode));
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _decode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }
}

/// Global provider for the user's preferred [ThemeMode].
final StateNotifierProvider<ThemeNotifier, ThemeMode> themeModeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) => ThemeNotifier());