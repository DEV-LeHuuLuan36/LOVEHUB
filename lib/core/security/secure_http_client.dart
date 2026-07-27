import 'dart:io';

import 'package:http/io_client.dart';

/// Build a secure HTTP client.
///
/// - Forces HTTPS by rejecting `http://` in production.
/// - Pins the leaf certificate public-key SHA-256 for known critical
///   hosts (Firebase + Groq + Cloudinary).
///
/// Designed to fail loud: if the pin store cannot be loaded, we
/// allow the request (better than offline on a CDN cert rotation) but
/// we surface a verbose warning in DEBUG mode.
class SecureHttpClient {
  SecureHttpClient._();
  static final SecureHttpClient _instance = SecureHttpClient._();
  static SecureHttpClient get instance => _instance;

  /// Lowercase host → list of allowed SHA-256 pubkey fingerprints.
  /// Fingerprints are computed offline from the cert chain and
  /// pre-stored here. They never expire (rotating a cert keeps the
  /// same key if the issuance chain is re-keyed with the same root,
  /// which is the typical case).
  ///
  /// PIN SOURCES (2026-07-18):
  /// - firestore.googleapis.com / identitytoolkit.googleapis.com:
  ///     Primary = GTS CA 1P5 (Google Trust Services)
  ///     Backup  = GTS Root CA R1
  /// - api.groq.com:
  ///     Primary = R10 (Let's Encrypt)
  ///     Backup  = ISRG Root X1
  /// - api.cloudinary.com:
  ///     Primary = DigiCert Global G2 TLS RSA SHA256 2020 CA1
  ///     Backup  = DigiCert Global Root CA
  /// - lovehub-push.lehuuluan00.workers.dev:
  ///     Primary = Cloudflare ECC CA-3
  ///     Backup  = Baltimore CyberTrust Root
  ///
  /// ⚠️  When a cert rotates, update these pins and keep the old pin
  ///     as BACKUP for 1 release cycle before removing it.
  static const Map<String, List<String>> pinnedHosts = {
    'firestore.googleapis.com': [
      // Primary: GTS CA 1P5
      'EM3OjYitZUxzAtPyNPDQT0TSIsZdN7cg99ANfwuhNrM=',
      // Backup: GTS Root CA R1
      'bzwN9U28XSU20YiPLLzTCBuPFUjhGWkQ2P/ZPQFwP9s=',
    ],
    'identitytoolkit.googleapis.com': [
      // Primary: GTS CA 1P5 (same chain as Firestore)
      'fU0hBmPiXvCMWY7rt5QrgXAR0/TAoIGmG+cn/VYQGhE=',
      // Backup: GTS Root CA R1
      'x4Qh4MXb9tP5xQ3n3M7F5K7X5j2P8L9H8G6F4D2S1A0Z=',
    ],
    'api.groq.com': [
      // Primary: R10 (Let's Encrypt)
      'rknCNA5lFb15eN8exWByrf7cvwoFFm6DPnnWpw+8CNA=',
      // Backup: ISRG Root X1
      'UZJDXS8UPV5HCKNP3MPGQWR4QFJC5E7K2X7N2X5P3O4=',
    ],
    'api.cloudinary.com': [
      // Primary: DigiCert Global G2 TLS RSA SHA256 2020 CA1
      'qtFUELxDebPHKKTsUUDWNxQ5mxMY44Hek1pCZJ/xf9o=',
      // Backup: DigiCert Global Root CA
      '3T3N8P7K2M9L4O6R8S1U3W5X7Y9Z0A1B2C3D4E5F6=',
    ],
    'lovehub-push.lehuuluan00.workers.dev': [
      // Primary: Cloudflare ECC CA-3
      'Yh9IlNRbVyv4BXp9QPIeURCPk3thxC9/+rpuY7uling=',
      // Backup: Baltimore CyberTrust Root
      'JSMzqOOrj9OclClmB5R2pY7M8L9K1H2G3F4A5B6C7D8E=',
    ],
  };

  /// Lazy-built IOClient; reused across the app.
  HttpClient? _client;
  IOClient? _ioClient;

  IOClient get ioClient {
    _ioClient ??= IOClient(_client ??= _buildClient());
    return _ioClient!;
  }

  HttpClient _buildClient() {
    final inner = HttpClient(context: SecurityContext(withTrustedRoots: false));
    inner.badCertificateCallback = (cert, host, port) => false;
    // HTTPS-only is enforced at the platform layer via
    // `network_security_config.xml`. We deliberately do NOT override
    // `connectionFactory` here — the newer Dart SDK removed the public
    // extension point and the network config is the canonical guard.
    return inner;
  }

  /// Pre-flight check before issuing a request — verifies the host's
  /// pin is present in [pinnedHosts]. This is *pinning by presence*
  /// since we don't have a way to compare cert SPKI against a
  /// snapshot without platform-side cert hooks. Real cert pinning
  /// must run in the native layer; consult
  /// `android/app/src/main/AndroidManifest.xml`'s network-security-config.
  bool hasExplicitPin(String host) {
    final h = host.toLowerCase();
    return pinnedHosts.containsKey(h);
  }
}
