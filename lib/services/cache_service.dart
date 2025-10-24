import 'interfaces.dart';

/// Generic cache entry with timestamp
class CacheEntry<T> {
  final T value;
  final DateTime timestamp;

  const CacheEntry(this.value, this.timestamp);

  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(timestamp) > maxAge;
  }
}

/// Service for centralized caching with invalidation
class CacheService implements ICacheService {
  final Map<String, CacheEntry<dynamic>> _cache = {};
  final Map<String, Duration> _defaultMaxAges = {};

  /// Set default max age for a cache key
  @override
  void setDefaultMaxAge(String key, Duration maxAge) {
    _defaultMaxAges[key] = maxAge;
  }

  /// Get cached value if not expired
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    final maxAge = _defaultMaxAges[key] ?? const Duration(seconds: 1);
    if (entry.isExpired(maxAge)) {
      _cache.remove(key);
      return null;
    }

    return entry.value as T;
  }

  /// Set cached value with current timestamp
  void set<T>(String key, T value) {
    _cache[key] = CacheEntry(value, DateTime.now());
  }

  /// Check if cache contains valid entry
  bool contains(String key) {
    final entry = _cache[key];
    if (entry == null) return false;

    final maxAge = _defaultMaxAges[key] ?? const Duration(seconds: 1);
    if (entry.isExpired(maxAge)) {
      _cache.remove(key);
      return false;
    }

    return true;
  }

  /// Invalidate specific cache entry
  @override
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// Invalidate all cache entries
  @override
  void invalidateAll() {
    _cache.clear();
  }

  /// Invalidate entries matching pattern
  void invalidatePattern(bool Function(String) pattern) {
    final keysToRemove = _cache.keys.where(pattern).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  /// Get or compute value with caching
  @override
  T getOrCompute<T>(String key, T Function() compute) {
    final cached = get<T>(key);
    if (cached != null) return cached;

    final value = compute();
    set(key, value);
    return value;
  }

  /// Clear expired entries
  void clearExpired() {
    final keysToRemove = <String>[];

    for (final entry in _cache.entries) {
      final maxAge = _defaultMaxAges[entry.key] ?? const Duration(seconds: 1);
      if (entry.value.isExpired(maxAge)) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'totalEntries': _cache.length,
      'defaultMaxAges': _defaultMaxAges.length,
    };
  }
}
