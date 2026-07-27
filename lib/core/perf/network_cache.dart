import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// In-process memoisation for derived data that doesn't change
/// during a session.
///
/// Two flavours:
///   - [memoize] returns the same value within [ttl] for the same
///     key.
///   - [streamMemoize] returns the same `Stream<T>` within [ttl]
///     so consumers can re-subscribe without re-fetching.
///
/// We deliberately do NOT use this for security-sensitive data —
/// anything that goes through Firebase Security Rules must hit the
/// server every time.
class NetworkCache {
  NetworkCache._();
  static final NetworkCache _instance = NetworkCache._();
  static NetworkCache get instance => _instance;

  static const int maxEntries = 256;

  final LinkedHashMap<String, _CacheEntry> _store =
      LinkedHashMap<String, _CacheEntry>();

  /// Total hits across all keys since process start.
  int hits = 0;
  int misses = 0;

  T? get<T>(String key) {
    final e = _store[key];
    if (e == null) {
      misses += 1;
      return null;
    }
    if (e.isExpired) {
      _store.remove(key);
      misses += 1;
      return null;
    }
    hits += 1;
    // Move to MRU position.
    _store.remove(key);
    _store[key] = e;
    return e.value as T;
  }

  void set<T>(String key, T value, {Duration ttl = const Duration(minutes: 5)}) {
    if (_store.length >= maxEntries) {
      // LRU eviction: drop the oldest.
      _store.remove(_store.keys.first);
    }
    _store[key] = _CacheEntry(value, ttl);
  }

  void invalidate(String key) => _store.remove(key);

  void invalidateByPrefix(String prefix) {
    _store.removeWhere((k, _) => k.startsWith(prefix));
  }

  void clear() {
    _store.clear();
    hits = 0;
    misses = 0;
  }

  /// Cache hit ratio (0.0..1.0).
  double get hitRatio {
    final total = hits + misses;
    if (total == 0) return 0;
    return hits / total;
  }

  @visibleForTesting
  int get size => _store.length;
}

class _CacheEntry {
  _CacheEntry(this.value, this.ttl)
      : expiresAt = DateTime.now().add(ttl);
  final Object? value;
  final Duration ttl;
  final DateTime expiresAt;
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Convenience: wrap a fetch fn with memoisation.
Future<T> memoizedFetch<T>(
  String key,
  Future<T> Function() fetch, {
  Duration ttl = const Duration(minutes: 5),
}) async {
  final cached = NetworkCache.instance.get<T>(key);
  if (cached != null) return cached;
  final fresh = await fetch();
  NetworkCache.instance.set<T>(key, fresh, ttl: ttl);
  return fresh;
}

/// Cache-busting helper for Firestore reads. The user profile doc,
/// couple doc, and settings rarely change between mutations — we
/// can reuse the result for 30 s without paying for a network
/// round-trip.
class FirestoreCacheProfile {
  FirestoreCacheProfile({
    this.profileTtl = const Duration(seconds: 30),
    this.coupleTtl = const Duration(seconds: 30),
    this.streakTtl = const Duration(seconds: 15),
  });

  final Duration profileTtl;
  final Duration coupleTtl;
  final Duration streakTtl;

  /// Default profile tuned for a chat-like app: aggressive cache on
  /// static-ish data, short cache on real-time data.
  static final FirestoreCacheProfile aggressive =
      FirestoreCacheProfile();
}