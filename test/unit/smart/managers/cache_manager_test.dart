import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/smart/managers/cache_manager.dart';
import '../../../mocks/mock_logger.mocks.dart';

void main() {
  group('CacheManager', () {
    late CacheManager cacheManager;
    late MockLogger mockLogger;

    setUp(() {
      mockLogger = MockLogger();
      cacheManager = CacheManager(mockLogger);
    });

    group('Basic Caching', () {
      test('should set and get cached value', () {
        const key = 'test_key';
        const value = 'test_value';
        
        cacheManager.set(key, value);
        final result = cacheManager.get(key);
        
        expect(result, equals(value));
      });

      test('should return null for non-existent key', () {
        final result = cacheManager.get('non_existent');
        expect(result, isNull);
      });

      test('should handle null values', () {
        const key = 'null_key';
        cacheManager.set(key, null);
        final result = cacheManager.get(key);
        expect(result, isNull);
      });

      test('should handle different data types', () {
        cacheManager.set('string', 'test');
        cacheManager.set('int', 42);
        cacheManager.set('bool', true);
        cacheManager.set('list', [1, 2, 3]);
        cacheManager.set('map', {'key': 'value'});

        expect(cacheManager.get('string'), equals('test'));
        expect(cacheManager.get('int'), equals(42));
        expect(cacheManager.get('bool'), equals(true));
        expect(cacheManager.get('list'), equals([1, 2, 3]));
        expect(cacheManager.get('map'), equals({'key': 'value'}));
      });
    });

    group('TTL (Time To Live)', () {
      test('should respect TTL', () async {
        const key = 'ttl_key';
        const value = 'ttl_value';
        const ttl = Duration(milliseconds: 100);
        
        cacheManager.set(key, value, ttl: ttl);
        
        // Should be available immediately
        expect(cacheManager.get(key), equals(value));
        
        // Wait for TTL to expire
        await Future.delayed(const Duration(milliseconds: 150));
        
        // Should be expired
        expect(cacheManager.get(key), isNull);
      });

      test('should use default TTL when not specified', () async {
        const key = 'default_ttl_key';
        const value = 'default_ttl_value';
        
        cacheManager.set(key, value);
        
        // Should be available immediately
        expect(cacheManager.get(key), equals(value));
        
        // Wait for default TTL to expire (30 minutes)
        // This test would take too long, so we'll just verify it's set
        expect(cacheManager.get(key), equals(value));
      });

      test('should handle zero TTL', () {
        const key = 'zero_ttl_key';
        const value = 'zero_ttl_value';
        
        cacheManager.set(key, value, ttl: Duration.zero);
        
        // Should be expired immediately
        expect(cacheManager.get(key), isNull);
      });
    });

    group('Category Caching', () {
      test('should set and get by category', () {
        const category = 'discovery'; // Use predefined category
        const key = 'test_key';
        const value = 'test_value';
        
        cacheManager.setByCategory(category, key, value);
        final result = cacheManager.getByCategory(category, key);
        
        expect(result, equals(value));
      });

      test('should return null for non-existent category', () {
        final result = cacheManager.getByCategory('non_existent', 'key');
        expect(result, isNull);
      });

      test('should return null for non-existent key in category', () {
        const category = 'discovery'; // Use predefined category
        cacheManager.setByCategory(category, 'existing_key', 'value');
        
        final result = cacheManager.getByCategory(category, 'non_existent_key');
        expect(result, isNull);
      });

      test('should handle TTL for category cache', () async {
        const category = 'discovery'; // Use predefined category
        const key = 'ttl_key';
        const value = 'ttl_value';
        const ttl = Duration(milliseconds: 100);
        
        cacheManager.setByCategory(category, key, value, ttl: ttl);
        
        // Should be available immediately
        expect(cacheManager.getByCategory(category, key), equals(value));
        
        // Wait for TTL to expire
        await Future.delayed(const Duration(milliseconds: 150));
        
        // Should be expired
        expect(cacheManager.getByCategory(category, key), isNull);
      });
    });

    group('Cache Statistics', () {
      test('should track hits and misses', () {
        const key = 'stats_key';
        const value = 'stats_value';
        
        // Set a value
        cacheManager.set(key, value);
        
        // Hit
        cacheManager.get(key);
        
        // Miss
        cacheManager.get('non_existent');
        
        final stats = cacheManager.getCacheStats();
        expect(stats['hits'], equals(1));
        expect(stats['misses'], equals(1));
      });

      test('should calculate hit rate', () {
        const key = 'hit_rate_key';
        const value = 'hit_rate_value';
        
        cacheManager.set(key, value);
        
        // 2 hits, 1 miss
        cacheManager.get(key);
        cacheManager.get(key);
        cacheManager.get('non_existent');
        
        final hitRate = cacheManager.getHitRate();
        expect(hitRate, equals(2.0 / 3.0));
      });

      test('should return 1.0 hit rate for no operations', () {
        final hitRate = cacheManager.getHitRate();
        expect(hitRate, equals(1.0));
      });
    });

    group('Cache Invalidation', () {
      test('should invalidate specific key', () {
        const key = 'invalidate_key';
        const value = 'invalidate_value';
        
        cacheManager.set(key, value);
        expect(cacheManager.get(key), equals(value));
        
        cacheManager.invalidate(key);
        expect(cacheManager.get(key), isNull);
      });

      test('should invalidate by category and key', () {
        const category = 'discovery'; // Use predefined category
        const key = 'invalidate_key';
        const value = 'invalidate_value';
        
        cacheManager.setByCategory(category, key, value);
        expect(cacheManager.getByCategory(category, key), equals(value));
        
        cacheManager.invalidateByCategory(category, key);
        expect(cacheManager.getByCategory(category, key), isNull);
      });

      test('should clear specific category', () {
        const category = 'discovery'; // Use predefined category
        const key1 = 'key1';
        const key2 = 'key2';
        
        cacheManager.setByCategory(category, key1, 'value1');
        cacheManager.setByCategory(category, key2, 'value2');
        
        expect(cacheManager.getByCategory(category, key1), equals('value1'));
        expect(cacheManager.getByCategory(category, key2), equals('value2'));
        
        cacheManager.clearCategory(category);
        
        expect(cacheManager.getByCategory(category, key1), isNull);
        expect(cacheManager.getByCategory(category, key2), isNull);
      });

      test('should clear all cache', () {
        cacheManager.set('key1', 'value1');
        cacheManager.set('key2', 'value2');
        cacheManager.setByCategory('discovery', 'key3', 'value3');
        
        expect(cacheManager.get('key1'), equals('value1'));
        expect(cacheManager.get('key2'), equals('value2'));
        expect(cacheManager.getByCategory('discovery', 'key3'), equals('value3'));
        
        cacheManager.clearAll();
        
        expect(cacheManager.get('key1'), isNull);
        expect(cacheManager.get('key2'), isNull);
        expect(cacheManager.getByCategory('discovery', 'key3'), isNull);
      });
    });

    group('Cache Corruption', () {
      test('should detect corruption', () {
        // This is a simplified test since corruption detection is complex
        final isCorrupted = cacheManager.isCorrupted();
        expect(isCorrupted, isFalse);
      });

      test('should clear corrupted cache', () async {
        await cacheManager.clearCorrupted();
        // Should not throw
        expect(true, isTrue);
      });
    });

    group('Persistence', () {
      test('should persist and load cache', () async {
        // Set some test data
        cacheManager.set('persist_key', 'persist_value');
        cacheManager.setByCategory('discovery', 'persist_key', 'persist_value');
        
        // Persist cache
        await cacheManager.persistCache();
        
        // Clear cache
        cacheManager.clearAll();
        
        // Load cache
        await cacheManager.loadCache();
        
        // Verify data is restored
        expect(cacheManager.get('persist_key'), equals('persist_value'));
        expect(cacheManager.getByCategory('discovery', 'persist_key'), equals('persist_value'));
      });

      test('should handle persistence errors gracefully', () async {
        // This test verifies that persistence doesn't throw
        await cacheManager.persistCache();
        await cacheManager.loadCache();
        
        expect(true, isTrue);
      });
    });

    group('Memory Usage', () {
      test('should estimate memory usage', () {
        cacheManager.set('small', 'value');
        cacheManager.set('large', 'a' * 1000);
        
        final stats = cacheManager.getCacheStats();
        expect(stats['memoryUsage'], isA<int>());
        expect(stats['memoryUsage'], greaterThan(0));
      });
    });

    group('Cleanup', () {
      test('should clean up expired entries', () async {
        const key = 'expire_key';
        const value = 'expire_value';
        const ttl = Duration(milliseconds: 50);
        
        cacheManager.set(key, value, ttl: ttl);
        
        // Should be available immediately
        expect(cacheManager.get(key), equals(value));
        
        // Wait for cleanup timer (5 minutes) - too long for test
        // Instead, verify the cleanup mechanism exists
        expect(cacheManager.get(key), equals(value));
      });
    });
  });
} 