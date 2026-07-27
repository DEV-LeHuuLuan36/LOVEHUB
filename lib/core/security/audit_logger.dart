import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Append-only on-device audit log for security-relevant events.
///
/// We deliberately keep this *local*: the values are not PII, and a
/// remote log would itself be an attack surface. A future cloud
/// function (Layer 10+) could scrape /audit-logs/{uid} for SOC review.
enum AuditSeverity { info, warn, error }

class AuditEvent {
  AuditEvent({
    required this.kind,
    required this.severity,
    Map<String, Object?>? fields,
  }) : fields = fields ?? <String, Object?>{};

  final String kind;
  final AuditSeverity severity;
  final Map<String, Object?> fields;
  final DateTime at = DateTime.now();

  Map<String, Object?> toJson() => <String, Object?>{
        'k': kind,
        's': severity.name,
        'at': at.toIso8601String(),
        ...fields,
      };

  @override
  String toString() => '${severity.name.toUpperCase()} $kind $fields';
}

/// Single-file JSON-lines audit log with size-based rotation.
class AuditLogger {
  AuditLogger._();
  static final AuditLogger _instance = AuditLogger._();
  static AuditLogger get instance => _instance;

  static const int _maxBytes = 5 * 1024 * 1024; // 5 MiB per file
  static const int _maxFiles = 3;              // keep 3 rotations
  static const String _baseName = 'lovehub_audit.log';

  File? _file;
  IOSink? _sink;

  Future<void> _ensureOpen() async {
    if (_sink != null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/$_baseName');
      if (await _file!.length() >= _maxBytes) {
        await _rotate();
      }
      _sink = _file!.openWrite(mode: FileMode.append);
    } catch (e) {
      // If we can't open the log (sandbox, missing perms), fall back to
      // debug-only console logging so the app keeps working.
      _sink = null;
      debugPrint('[AUDIT-FALLBACK] $e');
    }
  }

  Future<void> _rotate() async {
    // Close current, rename to .1, delete oldest.
    if (_file == null) return;
    _sink?.flush();
    await _sink?.close();
    _sink = null;
    for (var i = _maxFiles; i >= 1; i--) {
      final src = File('${_file!.path}.${i - 1 == 0 ? '' : '${i - 1}'}');
      if (!src.existsSync()) continue;
      final dst = File('${_file!.path}.$i');
      if (dst.existsSync()) await dst.delete();
      await src.rename(dst.path);
    }
    if (_file!.existsSync()) await _file!.delete();
  }

  Future<void> append(AuditEvent event) async {
    final json = event.toJson();
    // Auto-add a uid stamp when Firebase is authenticated.
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) json['uid'] = user.uid;
    } catch (_) {/* not ready */}

    await _ensureOpen();
    if (_sink != null) {
      _sink!.writeln(json.toString());
    } else {
      debugPrint('[AUDIT] ${event.toString()}');
    }
  }

  Future<void> flush() async => _sink?.flush();

  /// Read all stored audit lines (admin / debug only).
  Future<List<String>> readAll() async {
    final dir = await getApplicationDocumentsDirectory();
    final lines = <String>[];
    for (var i = 0; i <= _maxFiles; i++) {
      final f = File(i == 0
          ? '${dir.path}/$_baseName'
          : '${dir.path}/$_baseName.$i');
      if (!await f.exists()) continue;
      lines.addAll(await f.readAsLines());
    }
    return lines;
  }
}

/// Convenience helpers — keep call sites short.
Future<void> auditInfo(String kind, {Map<String, Object?>? fields}) =>
    AuditLogger.instance.append(
      AuditEvent(kind: kind, severity: AuditSeverity.info, fields: fields),
    );

Future<void> auditWarn(String kind, {Map<String, Object?>? fields}) =>
    AuditLogger.instance.append(
      AuditEvent(kind: kind, severity: AuditSeverity.warn, fields: fields),
    );

Future<void> auditError(String kind, {Map<String, Object?>? fields}) =>
    AuditLogger.instance.append(
      AuditEvent(kind: kind, severity: AuditSeverity.error, fields: fields),
    );
