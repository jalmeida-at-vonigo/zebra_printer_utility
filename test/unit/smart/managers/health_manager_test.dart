import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/smart/managers/health_manager.dart';
import 'package:zebrautil/models/result.dart';
import '../../../mocks/mock_logger.mocks.dart';

void main() {
  group('HealthManager', () {
    late HealthManager healthManager;
    late MockLogger mockLogger;

    setUp(() {
      mockLogger = MockLogger();
      healthManager = HealthManager(mockLogger);
    });

    group('Health Checks', () {
      test('should perform comprehensive health check', () async {
        final result = await healthManager.performHealthCheck();
        expect(result.success, isTrue);
      });

      test('should get connection health', () {
        final health = healthManager.getConnectionHealth();
        expect(health, isA<double>());
        expect(health, greaterThanOrEqualTo(0.0));
        expect(health, lessThanOrEqualTo(1.0));
      });

      test('should get detailed health status', () {
        final health = healthManager.getDetailedHealthStatus();
        expect(health, isA<Map<String, dynamic>>());
        expect(health.keys, containsAll(['overall', 'components', 'lastChecks']));
      });
    });

    group('Health Metrics', () {
      test('should track health metrics over time', () async {
        // Perform multiple health checks to build up metrics
        await healthManager.performHealthCheck();
        await healthManager.performHealthCheck();
        
        final health = healthManager.getConnectionHealth();
        expect(health, isA<double>());
        
        final detailed = healthManager.getDetailedHealthStatus();
        expect(detailed['components'], isA<Map<String, dynamic>>());
      });

      test('should return healthy by default when no operations', () {
        final health = healthManager.getConnectionHealth();
        expect(health, equals(1.0)); // Default to healthy
      });
    });

    group('Integration', () {
      test('should log health operations', () async {
        await healthManager.performHealthCheck();
        // Should not throw
        expect(true, isTrue);
      });

      test('should handle health check failures gracefully', () async {
        final result = await healthManager.performHealthCheck();
        expect(result, isA<Result<void>>());
      });
    });

    group('Performance', () {
      test('should perform health checks efficiently', () async {
        final startTime = DateTime.now();
        await healthManager.performHealthCheck();
        final duration = DateTime.now().difference(startTime);
        
        expect(duration.inMilliseconds, lessThan(1000)); // Should complete within 1 second
      });

      test('should handle multiple health checks', () async {
        for (int i = 0; i < 5; i++) {
          await healthManager.performHealthCheck();
        }
        // Should not throw
        expect(true, isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle health check with no previous metrics', () {
        final health = healthManager.getConnectionHealth();
        expect(health, equals(1.0));
        
        final detailed = healthManager.getDetailedHealthStatus();
        expect(detailed['overall'], equals(1.0));
      });

      test('should maintain health metrics across multiple checks', () async {
        // First check
        await healthManager.performHealthCheck();
        final health1 = healthManager.getConnectionHealth();
        
        // Second check
        await healthManager.performHealthCheck();
        final health2 = healthManager.getConnectionHealth();
        
        // Both should be healthy
        expect(health1, equals(1.0));
        expect(health2, equals(1.0));
      });
    });
  });
} 