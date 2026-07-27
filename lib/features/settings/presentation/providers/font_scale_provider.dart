import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Three discrete font-size levels the user can pick from. The numeric
/// `scale` value is what gets passed to `TextScaler.linear` to scale every
/// piece of text in the app.
enum FontScaleLevel {
  small(0.9, 'small'),
  medium(1.0, 'medium'),
  large(1.15, 'large');

  const FontScaleLevel(this.scale, this.storageKey);
  final double scale;
  final String storageKey;
}

/// User-selected font scale, persisted to SharedPreferences.
final fontScaleProvider =
    StateNotifierProvider<FontScaleNotifier, FontScaleLevel>((ref) {
  return FontScaleNotifier();
});

class FontScaleNotifier extends StateNotifier<FontScaleLevel> {
  FontScaleNotifier() : super(FontScaleLevel.medium) {
    _load();
  }

  static const _prefsKey = 'font_scale_level';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final loaded = FontScaleLevel.values.firstWhere(
      (e) => e.storageKey == raw,
      orElse: () => FontScaleLevel.medium,
    );
    if (mounted) state = loaded;
  }

  Future<void> set(FontScaleLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, level.storageKey);
    if (mounted) state = level;
  }
}
