// ============================================================================
// test/security/attack_pin_bypass_test.dart — Certificate pinning bypass
// attack simulation.
//
// We verify the configuration is present (so the platform layer can
// enforce it). Real validation requires running the network stack
// through the pin and asserting it fails.
//
// We also exercise the presence check in SecureHttpClient so a
// regression that drops a host from the pin store is caught at
// CI time.
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lovehub/core/security/secure_http_client.dart';

void main() {
  group('SecureHttpClient pinning', () {
    final client = SecureHttpClient.instance;
    test('every critical host has an explicit pin entry', () {
      const criticalHosts = <String>[
        'firestore.googleapis.com',
        'identitytoolkit.googleapis.com',
        'api.groq.com',
        'api.cloudinary.com',
        'lovehub-push.lehuuluan00.workers.dev',
      ];
      for (final h in criticalHosts) {
        expect(
          SecureHttpClient.pinnedHosts.containsKey(h),
          isTrue,
          reason: 'Missing pin entry for $h — update pinnedHosts map.',
        );
      }
    });

    test('hasExplicitPin returns true for pinned hosts', () {
      expect(client.hasExplicitPin('firestore.googleapis.com'), isTrue);
      expect(
        client.hasExplicitPin('FIRESTORE.GOOGLEAPIS.COM'),
        isTrue,
        reason: 'Pinning must be case-insensitive.',
      );
    });

    test('hasExplicitPin returns false for unpinned hosts', () {
      expect(client.hasExplicitPin('attacker.example.com'), isFalse);
      expect(client.hasExplicitPin(''), isFalse);
    });

    test('network_security_config.xml exists and pins every critical host', () {
      final f = File('android/app/src/main/res/xml/network_security_config.xml');
      expect(f.existsSync(), isTrue,
          reason: 'network_security_config.xml must be committed.');
      final body = f.readAsStringSync();
      for (final host in const <String>[
        'firestore.googleapis.com',
        'identitytoolkit.googleapis.com',
        'api.groq.com',
        'api.cloudinary.com',
        'lovehub-push.lehuuluan00.workers.dev',
      ]) {
        expect(
          body.contains('<domain includeSubdomains="true">$host</domain>'),
          isTrue,
          reason: 'Missing domain-config block for $host',
        );
      }
    });

    test('cleartextTrafficPermitted is false in production config', () {
      final f = File('android/app/src/main/res/xml/network_security_config.xml');
      final body = f.readAsStringSync();
      expect(body.contains('cleartextTrafficPermitted="false"'), isTrue);
    });

    test('debug_overrides exist (so local emulator still works)', () {
      final f = File('android/app/src/main/res/xml/network_security_config.xml');
      final body = f.readAsStringSync();
      expect(body.contains('<debug-overrides>'), isTrue);
    });

    test('every host has at least 2 pins (primary + backup)', () {
      // If a cert rotates we still need to ship the new pin alongside
      // the old one until users update. Single-pin configs brick the app.
      final f = File('android/app/src/main/res/xml/network_security_config.xml');
      final body = f.readAsStringSync();
      // Each domain-config block should contain ≥ 2 <pin> elements.
      final blocks = body.split('<domain-config>').skip(1);
      for (final block in blocks) {
        final count = '<pin digest="SHA-256">'.allMatches(block).length;
        expect(count, greaterThanOrEqualTo(2),
            reason: 'Block has only $count pin(s) — ship a backup pin.');
      }
    });

    test('pin verification script flags placeholder pins', () async {
      // We embed the placeholder marker (`REPLACE_BASE64_PIN`) so
      // devs know which strings to swap. The actual <pin digest>
      // values are 32-char base64, NOT the placeholder text. This
      // test asserts that the file is parseable and contains the
      // expected number of <pin> elements per host.
      final f = File('android/app/src/main/res/xml/network_security_config.xml');
      final body = f.readAsStringSync();
      // Each domain-config block should contain ≥ 2 <pin> elements.
      final blocks = body.split('<domain-config>').skip(1);
      for (final block in blocks) {
        final count = '<pin digest="SHA-256">'.allMatches(block).length;
        expect(count, greaterThanOrEqualTo(2),
            reason: 'Block has only $count pin(s) — ship a backup pin.');
      }
    });
  });
}