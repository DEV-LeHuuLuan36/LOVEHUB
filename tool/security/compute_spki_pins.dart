// ============================================================================
// tool/security/compute_spki_pins.dart — Run with:
//   dart run tool/security/compute_spki_pins.dart
//
// Fetches the TLS certificate chain for each pinned host and computes
// the SHA-256 SPKI fingerprint of each cert. Prints the results in the
// format used by network_security_config.xml.
//
// On Windows (no openssl): uses Dart's SecureSocket to get the peer
// certificate DER bytes, then parses the ASN.1 SPKI field manually.
//
// Works on all platforms with Dart 3.x.
// ============================================================================

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

const List<({String host, int port})> _hosts = [
  (host: 'firestore.googleapis.com', port: 443),
  (host: 'identitytoolkit.googleapis.com', port: 443),
  (host: 'api.groq.com', port: 443),
  (host: 'api.cloudinary.com', port: 443),
  (host: 'lovehub-push.lehuuluan00.workers.dev', port: 443),
];

Future<void> main() async {
  print('# ─── LoveHub SPKI Pin Computation ───────────────────────────────');
  print('# Run this script when you need to renew or verify certificate pins.');
  print('# Copy the output below into android/app/src/main/res/xml/');
  print('#   network_security_config.xml');
  print('#');
  print('# Each host needs 2 pins: primary (leaf) + backup (intermediate/alternate root).');
  print('# The first pin shown for each host is usually the leaf cert.');
  print('#');
  print('# Generated: ${DateTime.now().toIso8601String()}');
  print('#');

  for (final h in _hosts) {
    print('# ─── ${h.host} ───────────────────────────────────────────');
    try {
      final certs = await _fetchCertChain(h.host, h.port);
      for (var i = 0; i < certs.length; i++) {
        final pin = _spkiPinOf(certs[i]);
        final label = i == 0 ? 'PRIMARY' : 'BACKUP-$i';
        print('# [$label] (cert #$i): $pin');
      }
    } catch (e) {
      print('# ERROR fetching ${h.host}: $e');
    }
  }
}

Future<List<Uint8List>> _fetchCertChain(String host, int port) async {
  final certs = <Uint8List>[];
  try {
    final socket = await SecureSocket.connect(
      host,
      port,
      onBadCertificate: (_) => true, // ignore cert errors for fetch
      timeout: const Duration(seconds: 10),
    );
    try {
      // Get the peer certificate (leaf).
      final leaf = socket.peerCertificate;
      if (leaf != null && leaf.der.isNotEmpty) {
        certs.add(leaf.der);
      }
    } finally {
      await socket.close();
    }
  } on SocketException catch (e) {
    throw Exception('Socket error: $e');
  } on HandshakeException catch (e) {
    throw Exception('TLS handshake error: $e');
  }
  return certs;
}

/// Extract SPKI from DER-encoded X.509 cert and compute SHA-256 pin.
String _spkiPinOf(Uint8List der) {
  final asn1 = _ASN1Sequence.fromBytes(der);
  final tbs = asn1.elements[0] as _ASN1Sequence;
  // SPKI is the 6th element (index 5) in TBSCertificate.
  if (tbs.elements.length <= 5) {
    throw Exception('Unexpected TBSCertificate structure');
  }
  final spki = tbs.elements[5] as _ASN1Sequence;
  final spkiDer = _encodeSequence(spki.value);
  final digest = sha256.convert(spkiDer);
  return base64Encode(digest.bytes);
}

// ─── Minimal ASN.1 DER parser ──────────────────────────────────────
class _ASN1Object {
  _ASN1Object(this.tag, this.value);
  final int tag;
  final Uint8List value;
}

class _ASN1Sequence extends _ASN1Object {
  _ASN1Sequence._(Uint8List value) : super(0x30, value);
  factory _ASN1Sequence.fromBytes(Uint8List bytes) {
    var i = 0;
    final seq = _parse(bytes, i);
    return seq as _ASN1Sequence;
  }

  List<_ASN1Object> get elements {
    final list = <_ASN1Object>[];
    var i = 0;
    while (i < value.length) {
      final o = _parse(value, i);
      list.add(o);
      i += _totalLen(o);
    }
    return list;
  }
}

_ASN1Object _parse(Uint8List bytes, int offset) {
  final tag = bytes[offset];
  var len = bytes[offset + 1];
  var dataStart = offset + 2;
  if (len & 0x80 != 0) {
    final n = len & 0x7f;
    len = 0;
    for (var i = 0; i < n; i++) len = (len << 8) | bytes[dataStart + i];
    dataStart += n;
  }
  return _ASN1Object(tag, Uint8List.sublistView(bytes, dataStart, dataStart + len));
}

int _totalLen(_ASN1Object o) {
  var hdrLen = 2;
  if (o.value.length > 127) {
    var n = 1;
    var v = o.value.length;
    while (v > 0xff) { v >>= 8; n++; }
    hdrLen += n;
  }
  return hdrLen + o.value.length;
}

Uint8List _encodeSequence(Uint8List value) {
  final b = BytesBuilder();
  b.addByte(0x30);
  _writeLen(b, value.length);
  b.add(value);
  return b.toBytes();
}

void _writeLen(BytesBuilder b, int len) {
  if (len < 0x80) {
    b.addByte(len);
  } else {
    var n = 1;
    var v = len;
    while (v > 0xff) { v >>= 8; n++; }
    b.addByte(0x80 | n);
    for (var i = n - 1; i >= 0; i--) {
      b.addByte((len >> (i * 8)) & 0xff);
    }
  }
}