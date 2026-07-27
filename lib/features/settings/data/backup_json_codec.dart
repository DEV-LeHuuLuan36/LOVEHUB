import 'dart:convert';
import 'package:lovehub/features/settings/domain/entities/backup_data.dart';

/// JSON serialization helpers for [BackupData].
/// Lives in the data layer but contains no Firebase deps — safe to
/// import from anywhere.
class BackupJsonCodec {
  BackupJsonCodec._();

  static String encode(BackupData data) =>
      const JsonEncoder.withIndent('  ').convert(data.toJson());

  static BackupData decode(String json) =>
      BackupData.fromJson(jsonDecode(json) as Map<String, dynamic>);
}
