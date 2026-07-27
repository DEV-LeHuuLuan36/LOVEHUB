import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lovehub/core/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TDD test for ThemeProvider persistence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Allow pending microtasks + SharedPreferences platform channel
  /// responses to complete. Must be called from a `testWidgets` body
  /// so we have access to a [WidgetTester] for `runAsync`.
  ///
  /// IMPORTANT: The caller must `read(themeModeProvider)` BEFORE calling
  /// settle, so the `ThemeNotifier` is instantiated and its
  /// `Future.microtask(_load)` is queued BEFORE the async window.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeProvider', () {
    testWidgets('default mode is ThemeMode.system when no preference is saved',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeProvider); // instantiate notifier
      await settle(tester);

      expect(container.read(themeModeProvider), equals(ThemeMode.system));
    });

    testWidgets('setMode(dark) updates state immediately', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeProvider); // instantiate notifier
      await settle(tester);

      await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), equals(ThemeMode.dark));
    });

    testWidgets('setMode(dark) persists to SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeProvider); // instantiate notifier
      await settle(tester);

      await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await settle(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), equals('dark'));
    });

    testWidgets('persisted dark mode survives app restart', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final c1 = ProviderContainer();
      c1.read(themeModeProvider);
      await settle(tester);
      await c1.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await settle(tester);
      c1.dispose();

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      c2.read(themeModeProvider); // instantiate notifier
      await settle(tester);

      expect(c2.read(themeModeProvider), equals(ThemeMode.dark));
    });

    testWidgets('persisted light mode is loaded on startup', (tester) async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeProvider); // instantiate notifier
      await settle(tester);

      expect(container.read(themeModeProvider), equals(ThemeMode.light));
    });

    testWidgets('persisted system mode is loaded on startup', (tester) async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'system'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeProvider); // instantiate notifier
      await settle(tester);

      expect(container.read(themeModeProvider), equals(ThemeMode.system));
    });

    testWidgets('setMode(light) then setMode(dark) persists the latest value',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeProvider); // instantiate notifier
      await settle(tester);

      await container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
      await settle(tester);
      await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await settle(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), equals('dark'));
      expect(container.read(themeModeProvider), equals(ThemeMode.dark));
    });

    testWidgets('invalid stored value falls back to ThemeMode.system',
        (tester) async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'invalid_value'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeProvider); // instantiate notifier
      await settle(tester);

      expect(container.read(themeModeProvider), equals(ThemeMode.system));
    });
  });
}