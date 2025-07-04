import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../internal/logger.dart';

/// Cache Manager with ZSDK result caching strategies
class CacheManager {
  final Logger _logger;
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, Duration> _cacheTtl = {};
  int _hits = 0;
  int _misses = 0;
  int _invalidations = 0;
  
  // Cache categories for different types of data
  final Map<String, Map<String, dynamic>> _categoryCache = {
    'discovery': {},
    'connection': {},
    'printer': {},
    'format': {},
    'command': {},
  };

  CacheManager(this._logger) {
    _startCleanupTimer();
  }

  /// Get cached value with TTL check
  dynamic get(String key, {Duration? ttl}) {
    if (_cache.containsKey(key)) {
      final timestamp = _cacheTimestamps[key];
      final itemTtl = ttl ?? _cacheTtl[key] ?? const Duration(minutes: 30);
      
      if (timestamp != null && DateTime.now().difference(timestamp) < itemTtl) {
        _hits++;
        _logger.debug('Cache hit for $key');
        return _cache[key];
      } else {
        // Cache expired, remove it
        _invalidations++;
        _logger.debug('Cache expired for $key, removing');
        _cache.remove(key);
        _cacheTimestamps.remove(key);
        _cacheTtl.remove(key);
      }
    }
    
    _misses++;
    _logger.debug('Cache miss for $key');
    return null;
  }

  /// Set cached value with TTL
  void set(String key, dynamic value, {Duration? ttl}) {
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();
    _cacheTtl[key] = ttl ?? const Duration(minutes: 30);
    _logger.debug('Cache set for $key with TTL: ${_cacheTtl[key]}');
  }

  /// Get cached value by category
  dynamic getByCategory(String category, String key, {Duration? ttl}) {
    final categoryMap = _categoryCache[category];
    if (categoryMap != null && categoryMap.containsKey(key)) {
      final timestamp = _cacheTimestamps['${category}_$key'];
      final itemTtl = ttl ?? _cacheTtl['${category}_$key'] ?? const Duration(minutes: 30);
      
      if (timestamp != null && DateTime.now().difference(timestamp) < itemTtl) {
        _hits++;
        _logger.debug('Category cache hit for $category:$key');
        return categoryMap[key];
      } else {
        // Cache expired, remove it
        _invalidations++;
        _logger.debug('Category cache expired for $category:$key, removing');
        categoryMap.remove(key);
        _cacheTimestamps.remove('${category}_$key');
        _cacheTtl.remove('${category}_$key');
      }
    }
    
    _misses++;
    _logger.debug('Category cache miss for $category:$key');
    return null;
  }

  /// Set cached value by category
  void setByCategory(String category, String key, dynamic value, {Duration? ttl}) {
    final categoryMap = _categoryCache[category];
    if (categoryMap != null) {
      categoryMap[key] = value;
      _cacheTimestamps['${category}_$key'] = DateTime.now();
      _cacheTtl['${category}_$key'] = ttl ?? const Duration(minutes: 30);
      _logger.debug('Category cache set for $category:$key with TTL: ${_cacheTtl['${category}_$key']}');
    }
  }

  /// Get cache hit rate
  double getHitRate() {
    final total = _hits + _misses;
    return total == 0 ? 1.0 : _hits / total;
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'hits': _hits,
      'misses': _misses,
      'invalidations': _invalidations,
      'hitRate': getHitRate(),
      'totalEntries': _cache.length,
      'categoryEntries': _categoryCache.map((k, v) => MapEntry(k, v.length)),
      'memoryUsage': _estimateMemoryUsage(),
    };
  }

  /// Check if cache is corrupted
  bool isCorrupted() {
    try {
      // Check for data integrity issues
      for (final entry in _cache.entries) {
        if (entry.value == null && _cacheTimestamps.containsKey(entry.key)) {
          return true; // Null value with timestamp indicates corruption
        }
      }
      
      // Check category cache integrity
      for (final category in _categoryCache.values) {
        for (final entry in category.entries) {
          if (entry.value == null && _cacheTimestamps.containsKey(entry.key)) {
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      _logger.error('Cache corruption check failed: $e');
      return true; // Assume corrupted if check fails
    }
  }

  /// Clear corrupted cache entries
  Future<void> clearCorrupted() async {
    if (isCorrupted()) {
      _logger.warning('Cache corruption detected, clearing cache');
      await clearAll();
    }
  }

  /// Clear all cache
  Future<void> clearAll() async {
    _logger.info('Clearing all cache');
    _cache.clear();
    _cacheTimestamps.clear();
    _cacheTtl.clear();
    
    for (final category in _categoryCache.values) {
      category.clear();
    }
    
    _hits = 0;
    _misses = 0;
    _invalidations = 0;
  }

  /// Clear specific category
  void clearCategory(String category) {
    _logger.info('Clearing cache category: $category');
    final categoryMap = _categoryCache[category];
    if (categoryMap != null) {
      // Remove timestamps and TTL for this category
      for (final key in categoryMap.keys) {
        _cacheTimestamps.remove('${category}_$key');
        _cacheTtl.remove('${category}_$key');
      }
      categoryMap.clear();
    }
  }

  /// Invalidate specific key
  void invalidate(String key) {
    _logger.debug('Invalidating cache key: $key');
    _cache.remove(key);
    _cacheTimestamps.remove(key);
    _cacheTtl.remove(key);
    _invalidations++;
  }

  /// Invalidate by category and key
  void invalidateByCategory(String category, String key) {
    _logger.debug('Invalidating category cache: $category:$key');
    final categoryMap = _categoryCache[category];
    if (categoryMap != null) {
      categoryMap.remove(key);
      _cacheTimestamps.remove('${category}_$key');
      _cacheTtl.remove('${category}_$key');
      _invalidations++;
    }
  }

  /// Persist cache to disk
  Future<void> persistCache() async {
    try {
      _logger.info('Persisting cache to disk');
      final cacheData = {
        'cache': _cache,
        'timestamps': _cacheTimestamps.map((k, v) => MapEntry(k, v.toIso8601String())),
        'ttl': _cacheTtl.map((k, v) => MapEntry(k, v.inMilliseconds)),
        'categoryCache': _categoryCache,
        'stats': {
          'hits': _hits,
          'misses': _misses,
          'invalidations': _invalidations,
        },
      };
      
      final cacheFile = File('${Directory.current.path}/.zebra_cache.json');
      await cacheFile.writeAsString(jsonEncode(cacheData));
      _logger.info('Cache persisted successfully');
    } catch (e) {
      _logger.error('Failed to persist cache: $e');
    }
  }

  /// Load cache from disk
  Future<void> loadCache() async {
    try {
      _logger.info('Loading cache from disk');
      final cacheFile = File('${Directory.current.path}/.zebra_cache.json');
      
      if (await cacheFile.exists()) {
        final cacheData = jsonDecode(await cacheFile.readAsString());
        
        _cache.clear();
        _cache.addAll(Map<String, dynamic>.from(cacheData['cache'] ?? {}));
        
        _cacheTimestamps.clear();
        final timestamps = Map<String, String>.from(cacheData['timestamps'] ?? {});
        for (final entry in timestamps.entries) {
          _cacheTimestamps[entry.key] = DateTime.parse(entry.value);
        }
        
        _cacheTtl.clear();
        final ttl = Map<String, int>.from(cacheData['ttl'] ?? {});
        for (final entry in ttl.entries) {
          _cacheTtl[entry.key] = Duration(milliseconds: entry.value);
        }
        
        _categoryCache.clear();
        final categoryData = Map<String, dynamic>.from(cacheData['categoryCache'] ?? {});
        for (final entry in categoryData.entries) {
          _categoryCache[entry.key] = Map<String, dynamic>.from(entry.value);
        }
        
        final stats = Map<String, dynamic>.from(cacheData['stats'] ?? {});
        _hits = stats['hits'] ?? 0;
        _misses = stats['misses'] ?? 0;
        _invalidations = stats['invalidations'] ?? 0;
        
        _logger.info('Cache loaded successfully');
      }
    } catch (e) {
      _logger.error('Failed to load cache: $e');
      // Clear cache if loading fails
      await clearAll();
    }
  }

  /// Start cleanup timer to remove expired entries
  void _startCleanupTimer() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      _cleanupExpiredEntries();
    });
  }

  /// Clean up expired cache entries
  void _cleanupExpiredEntries() {
    final now = DateTime.now();
    int cleanedCount = 0;
    
    // Clean main cache
    final expiredKeys = <String>[];
    for (final entry in _cacheTimestamps.entries) {
      final key = entry.key;
      final timestamp = entry.value;
      final ttl = _cacheTtl[key] ?? const Duration(minutes: 30);
      
      if (now.difference(timestamp) >= ttl) {
        expiredKeys.add(key);
      }
    }
    
    for (final key in expiredKeys) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
      _cacheTtl.remove(key);
      cleanedCount++;
    }
    
    // Clean category cache
    for (final category in _categoryCache.keys) {
      final categoryExpiredKeys = <String>[];
      for (final key in _categoryCache[category]!.keys) {
        final timestamp = _cacheTimestamps['${category}_$key'];
        final ttl = _cacheTtl['${category}_$key'] ?? const Duration(minutes: 30);
        
        if (timestamp != null && now.difference(timestamp) >= ttl) {
          categoryExpiredKeys.add(key);
        }
      }
      
      for (final key in categoryExpiredKeys) {
        _categoryCache[category]!.remove(key);
        _cacheTimestamps.remove('${category}_$key');
        _cacheTtl.remove('${category}_$key');
        cleanedCount++;
      }
    }
    
    if (cleanedCount > 0) {
      _logger.debug('Cleaned up $cleanedCount expired cache entries');
    }
  }

  /// Estimate memory usage of cache
  int _estimateMemoryUsage() {
    int size = 0;
    
    // Estimate main cache size
    for (final entry in _cache.entries) {
      size += entry.key.length * 2; // UTF-16 characters
      if (entry.value is String) {
        size += (entry.value as String).length * 2;
      } else if (entry.value is Map) {
        size += 100; // Rough estimate for maps
      } else if (entry.value is List) {
        size += 50; // Rough estimate for lists
      } else {
        size += 20; // Rough estimate for other types
      }
    }
    
    // Estimate category cache size
    for (final category in _categoryCache.values) {
      for (final entry in category.entries) {
        size += entry.key.length * 2;
        if (entry.value is String) {
          size += (entry.value as String).length * 2;
        } else {
          size += 50; // Rough estimate
        }
      }
    }
    
    return size;
  }

  /// Dispose resources
  void dispose() {
    persistCache();
  }
} 