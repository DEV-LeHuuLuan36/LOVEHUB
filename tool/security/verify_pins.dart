// ============================================================================
// tool/security/verify_pins.dart — CI gate that fails the build if
// the production `network_security_config.xml` still contains the
// `AAAA...=` placeholder pins.
//
// Usage:
//   dart run tool/security/verify_pins.dart
//
// Exits 0 if all pins look real, 1 if any host still has a placeholder.
// ============================================================================

import 'dart:io';

const List<String> _hosts = <String>[
  'firestore.googleapis.com',
  'identitytoolkit.googleapis.com',
  'api.groq.com',
  'api.cloudinary.com',
  'lovehub-push.lehuuluan00.workers.dev',
];

const String _placeholderA = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
const String _placeholderB = 'BACKUP_PIN_REPLACE_ME_AAAAAAAAAAAAAAAAAAAAAAAAAAA=';

Future<void> main() async {
  final config = File('android/app/src/main/res/xml/network_security_config.xml');
  if (!config.existsSync()) {
    stderr.writeln('ERROR: network_security_config.xml not found.');
    exit(2);
  }
  final text = await config.readAsString();

  final issues = <String>[];
  for (final host in _hosts) {
    if (!text.contains('<domain includeSubdomains="true">$host</domain>')) {
      issues.add('$host: no domain-config block found');
      continue;
    }
    if (text.contains(_placeholderA)) {
      // We allow up to 1 placeholder A (we may have already pinned
      // some hosts but not all). Fail if THIS host's block still
      // contains it.
      final blockStart = text.indexOf('<domain includeSubdomains="true">$host</domain>');
      final blockEnd = text.indexOf('</domain-config>', blockStart);
      final block = text.substring(blockStart, blockEnd);
      if (block.contains(_placeholderA) || block.contains(_placeholderB)) {
        issues.add('$host: still has placeholder pin(s)');
      }
    }
  }

  if (issues.isNotEmpty) {
    stderr.writeln('PIN VERIFICATION FAILED:');
    for (final i in issues) {
      stderr.writeln('  ✗ $i');
    }
    stderr.writeln(
      '\nFix: bash tool/security/compute_spki_pins.sh ${_hosts.join(' ')}',
    );
    exit(1);
  }

  stdout.writeln('✓ All ${_hosts.length} hosts have real pins.');
  exit(0);
}