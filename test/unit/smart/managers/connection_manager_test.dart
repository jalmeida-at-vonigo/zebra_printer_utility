import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/smart/managers/connection_manager.dart';
import 'package:zebrautil/smart/managers/cache_manager.dart';
import 'package:zebrautil/smart/options/discovery_options.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'package:zebrautil/zebra_printer.dart';
import '../../../mocks/mock_logger.mocks.dart';

// Fake ZebraPrinter for testing
class FakeZebraPrinter extends ZebraPrinter {
  FakeZebraPrinter(super.instanceId);
  @override
  Future<bool> isPrinterConnected() async => true;
  @override
  Future<Result<void>> disconnect() async => Result.success();
}

class TestConnectionManager extends ConnectionManager {
  TestConnectionManager(super.logger, {super.printerFactory});
}

void main() {
  group('ConnectionManager', () {
    late ConnectionManager connectionManager;
    late MockLogger mockLogger;
    late CacheManager cacheManager;

    setUp(() {
      mockLogger = MockLogger();
      cacheManager = CacheManager(mockLogger);
      connectionManager = TestConnectionManager(
        mockLogger,
        printerFactory: (instanceId) => FakeZebraPrinter(instanceId),
      );
      connectionManager.setCacheManager(cacheManager);
    });

    tearDown(() {
      connectionManager.dispose();
    });

    group('Connection Management', () {
      const testAddress = '192.168.1.100';

      test('should connect successfully', () async {
        final result = await connectionManager.connect(testAddress);
        expect(result.success, isTrue);
        expect(connectionManager.isConnected, isTrue);
        expect(connectionManager.currentAddress, equals(testAddress));
      }, skip: 'Platform-dependent test - needs proper mocking');

      test('should use cached connection if healthy', () async {
        // First connection
        await connectionManager.connect(testAddress);
        
        // Second connection should use cache
        final result = await connectionManager.connect(testAddress);
        expect(result.success, isTrue);
      }, skip: 'Platform-dependent test - needs proper mocking');

      test('should handle connection failures', () async {
        final result = await connectionManager.connect('invalid-address');
        expect(result.success, isFalse);
        expect(result.error?.code, ErrorCodes.connectionError);
      });

      test('should disconnect successfully', () async {
        await connectionManager.connect(testAddress);
        final result = await connectionManager.disconnect();
        expect(result.success, isTrue);
        expect(connectionManager.isConnected, isFalse);
        expect(connectionManager.currentAddress, isNull);
      });

      test('should handle multiple connection failures', () async {
        // Try to connect to invalid address multiple times
        for (int i = 0; i < 5; i++) {
          await connectionManager.connect('invalid-address');
        }
        
        // Should clear from pool after 3 failures
        final pool = connectionManager.getAllConnections();
        expect(pool.containsKey('invalid-address'), isFalse);
      });
    });

    group('Discovery', () {
      test('should discover printers', () async {
        final result = await connectionManager.discover();
        expect(result.success, isTrue);
        expect(result.data, isA<List<ZebraDevice>>());
      });

      test('should use cached discovery results', () async {
        // First discovery
        final result1 = await connectionManager.discover();
        expect(result1.success, isTrue);
        
        // Second discovery should use cache
        final result2 = await connectionManager.discover();
        expect(result2.success, isTrue);
        expect(result2.data, equals(result1.data));
      });

      test('should handle discovery with options', () async {
        const options = DiscoveryOptions(
          timeout: Duration(seconds: 2),
          includeBluetooth: true,
          includeNetwork: true,
        );
        final result = await connectionManager.discover(options: options);
        expect(result.success, isTrue);
      });
    });

    group('Health Monitoring', () {
      const testAddress = '192.168.1.100';

      test('should get connection health status', () {
        final health = connectionManager.getConnectionHealthStatus();
        expect(health, isA<Map<String, bool>>());
      });

      test('should get health metrics', () {
        final metrics = connectionManager.getHealthMetrics();
        expect(metrics, isA<Map<String, dynamic>>());
        expect(metrics.keys, containsAll([
          'totalConnections',
          'healthyConnections',
          'unhealthyConnections',
          'currentAddress',
          'isConnected',
        ]));
      });

      test('should check if connection is healthy', () {
        final isHealthy = connectionManager.isConnectionHealthy(testAddress);
        expect(isHealthy, isFalse); // No connection yet
      });

      test('should get connection age', () {
        final age = connectionManager.getConnectionAge(testAddress);
        expect(age, equals(-1)); // No connection yet
      });

      test('should force health check', () async {
        final isHealthy = await connectionManager.forceHealthCheck(testAddress);
        expect(isHealthy, isFalse); // No connection to check
      });

      test('should get failure statistics', () {
        final failures = connectionManager.getFailureStatistics();
        expect(failures, isA<Map<String, int>>());
      });

      test('should reset failure count', () {
        connectionManager.resetFailureCount('test-address');
        // Should not throw
        expect(true, isTrue);
      });
    });

    group('Pool Management', () {
      test('should get pool statistics', () {
        final stats = connectionManager.getPoolStatistics();
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.keys, containsAll([
          'totalConnections',
          'activeConnections',
          'staleConnections',
          'healthyConnections',
          'unhealthyConnections',
          'totalFailures',
        ]));
      });

      test('should get all connections', () {
        final connections = connectionManager.getAllConnections();
        expect(connections, isA<Map<String, dynamic>>());
      });

      test('should reset pool if needed', () async {
        await connectionManager.resetPoolIfNeeded();
        expect(connectionManager.isConnected, isFalse);
        expect(connectionManager.currentAddress, isNull);
      });

      test('should mark connection as unhealthy', () {
        connectionManager.markConnectionUnhealthy('test-address');
        expect(connectionManager.isConnected, isFalse);
      });
    });

    group('Caching Integration', () {
      test('should use cache manager for discovery', () async {
        // Set up cache
        cacheManager.setByCategory('discovery', 'last', [
          ZebraDevice(
            name: 'Test Printer',
            address: '192.168.1.100',
            isWifi: true,
            status: 'Available',
            isConnected: false,
          ),
        ]);

        final result = await connectionManager.discover();
        expect(result.success, isTrue);
        expect(result.data!.length, greaterThan(0));
      });
    });

    group('Error Handling', () {
      test('should handle connection errors gracefully', () async {
        final result = await connectionManager.connect('invalid-address');
        expect(result.success, isFalse);
        expect(result.error?.code, ErrorCodes.connectionError);
      });

      test('should handle discovery errors gracefully', () async {
        final result = await connectionManager.discover();
        // Should return success with empty list rather than failure
        expect(result.success, isTrue);
      });
    });

    group('Resource Management', () {
      test('should dispose resources properly', () {
        expect(() => connectionManager.dispose(), returnsNormally);
      });
    });
  });
} 