import 'package:flutter/foundation.dart';

/// Immutable snapshot of one member's most recent location as read
/// from Firestore. The location doc is shared by the partner app —
/// [updatedAt] is a server timestamp so it stays consistent across
/// devices; the UI uses it to decide whether the position is fresh
/// or stale (last-known).
@immutable
class MemberLocation {
  final double lat;
  final double lng;
  final DateTime? updatedAt;

  const MemberLocation({
    required this.lat,
    required this.lng,
    this.updatedAt,
  });

  /// True when we have no useful position to render — used by the
  /// screen to decide between showing a marker with a "last known"
  /// badge and showing a placeholder row.
  bool get hasPosition => updatedAt != null;

  /// We treat a position as "fresh" for 5 minutes. Anything older
  /// is rendered with a faded marker + a "last seen" label.
  bool get isFresh {
    final ts = updatedAt;
    if (ts == null) return false;
    return DateTime.now().difference(ts) < const Duration(minutes: 5);
  }

  MemberLocation copyWith({double? lat, double? lng, DateTime? updatedAt}) {
    return MemberLocation(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberLocation &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(lat, lng, updatedAt);
}