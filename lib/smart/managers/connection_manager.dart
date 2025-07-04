import 'dart:async';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'package:zebrautil/zebra_printer.dart';
import 'package:zebrautil/zebra_printer_discovery.dart';

import '../../internal/logger.dart';
import '../options/connect_options.dart';
import '../options/discovery_options.dart';
import 'cache_manager.dart';

/// Connection Manager with ZSDK integration and connection pooling
class ConnectionManager {
  final Logger _logger;
  final Map<String, ZebraPrinter> _connectionPool = {};
  final Map<String, ZebraDevice> _deviceCache = {};
  final Map<String, DateTime> _connectionTimestamps = {};
  final Map<String, int> _connectionFailureCounts = {};
  final Map<String, bool> _connectionHealth = {};
  final ZebraPrinter Function(String address) _printerFactory;
  
  String? currentAddress;
  bool isConnected = false;
  DateTime? _lastDiscoveryTime;
  List<ZebraDevice> _lastDiscoveredDevices = [];
  Timer? _healthCheckTimer;
  CacheManager? _cacheManager;

  /// Set the cache manager for connection and discovery caching
  void setCacheManager(CacheManager cacheManager) {
    _cacheManager = cacheManager;
  }

  ConnectionManager(this._logger, {ZebraPrinter Function(String address)? printerFactory})
      : _printerFactory = printerFactory ?? ((address) => ZebraPrinter(address)) {
    _startHealthCheckTimer();
  }

  /// Connect to printer using ZSDK with connection pooling
  Future<Result<void>> connect(String address, {ConnectOptions? options}) async {
    try {
      _logger.info('Connecting to printer using ZSDK: $address');
      
      // Check if we have a healthy cached connection
      if (_connectionPool.containsKey(address) && 
          isConnected && 
          currentAddress == address &&
          _connectionHealth[address] == true) {
        _logger.info('Using cached healthy connection for $address');
        return Result.success();
      }
      
      // Check connection failure count
      final failureCount = _connectionFailureCounts[address] ?? 0;
      if (failureCount > 3) {
        _logger.warning('Too many connection failures for $address, clearing from pool');
        _connectionPool.remove(address);
        _connectionFailureCounts.remove(address);
        _connectionHealth.remove(address);
      }
      
      // Create new connection using ZSDK
      final connection = await _createZSDKConnection(address, options);
      if (connection != null) {
        _connectionPool[address] = connection;
        currentAddress = address;
        isConnected = true;
        _connectionTimestamps[address] = DateTime.now();
        _connectionHealth[address] = true;
        _connectionFailureCounts.remove(address); // Clear failure count on success
        
        _logger.info('Successfully connected to $address using ZSDK');
        return Result.success();
      } else {
        _connectionFailureCounts[address] = failureCount + 1;
        return Result.error('Failed to create ZSDK connection', code: ErrorCodes.connectionError);
      }
    } catch (e, stack) {
      _logger.error('Connection failed', e, stack);
      _connectionFailureCounts[address] = (_connectionFailureCounts[address] ?? 0) + 1;
      return Result.error('Connection failed: $e', code: ErrorCodes.connectionError, dartStackTrace: stack);
    }
  }

  /// Disconnect from current printer
  Future<Result<void>> disconnect() async {
    try {
      if (currentAddress != null) {
        _logger.info('Disconnecting from $currentAddress');
        
        // Close ZSDK connection
        final connection = _connectionPool[currentAddress];
        if (connection != null) {
          await _closeZSDKConnection(connection);
        }
        
        _connectionPool.remove(currentAddress);
        _connectionHealth.remove(currentAddress);
        isConnected = false;
        currentAddress = null;
      }
      return Result.success();
    } catch (e, stack) {
      _logger.error('Disconnection failed', e, stack);
      return Result.error('Disconnection failed: $e', code: ErrorCodes.connectionError, dartStackTrace: stack);
    }
  }

  /// Discover available printers using ZSDK discovery
  Future<Result<List<ZebraDevice>>> discover({DiscoveryOptions? options}) async {
    try {
      _logger.info('Starting ZSDK printer discovery');
      final now = DateTime.now();

      // Try cache first
      if (_cacheManager != null) {
        final cached = _cacheManager!.getByCategory('discovery', 'last', ttl: const Duration(seconds: 30));
        if (cached != null && cached is List<ZebraDevice> && cached.isNotEmpty) {
          _logger.info('Using cached discovery results from CacheManager');
          return Result.success(cached);
        }
      }

      // Check if we have recent discovery results
      if (_lastDiscoveryTime != null && 
          now.difference(_lastDiscoveryTime!).inSeconds < 30 &&
          _lastDiscoveredDevices.isNotEmpty) {
        _logger.info('Using cached discovery results');
        return Result.success(_lastDiscoveredDevices);
      }
      
      // Perform ZSDK discovery
      final devices = await _performZSDKDiscovery(options);
      
      // Cache results
      _lastDiscoveryTime = now;
      _lastDiscoveredDevices = devices;
      
      // Update device cache
      for (final device in devices) {
        _deviceCache[device.address] = device;
      }

      // Store in CacheManager
      if (_cacheManager != null) {
        _cacheManager!.setByCategory('discovery', 'last', devices, ttl: const Duration(seconds: 30));
        for (final device in devices) {
          _cacheManager!.setByCategory('device', device.address, device, ttl: const Duration(minutes: 10));
        }
      }
      
      _logger.info('ZSDK discovery completed, found ${devices.length} devices');
      return Result.success(devices);
    } catch (e, stack) {
      _logger.error('Discovery failed', e, stack);
      return Result.error('Discovery failed: $e', code: ErrorCodes.discoveryError, dartStackTrace: stack);
    }
  }

  /// Reset connection pool if needed
  Future<void> resetPoolIfNeeded() async {
    _logger.info('Resetting connection pool');
    
    // Close all connections
    for (final entry in _connectionPool.entries) {
      try {
        await _closeZSDKConnection(entry.value);
      } catch (e) {
        _logger.warning('Failed to close connection for ${entry.key}: $e');
      }
    }
    
    _connectionPool.clear();
    _connectionTimestamps.clear();
    _connectionFailureCounts.clear();
    _connectionHealth.clear();
    isConnected = false;
    currentAddress = null;
  }

  /// Get all connections in pool
  Map<String, ZebraPrinter> getAllConnections() {
    return Map<String, ZebraPrinter>.from(_connectionPool);
  }

  /// Mark connection as unhealthy
  void markConnectionUnhealthy(String address) {
    _logger.warning('Marking connection as unhealthy: $address');
    _connectionPool.remove(address);
    _connectionHealth[address] = false;
    _connectionFailureCounts[address] = (_connectionFailureCounts[address] ?? 0) + 1;
    
    if (currentAddress == address) {
      isConnected = false;
      currentAddress = null;
    }
  }

  /// Create ZSDK connection using ZebraPrinter
  Future<ZebraPrinter?> _createZSDKConnection(String address, ConnectOptions? options) async {
    try {
      _logger.debug('Creating ZSDK connection for $address');
      
      // Create ZebraPrinter instance which handles ZSDK integration
      final printer = _printerFactory(address);
      
      // Test connection by checking if printer is reachable
      final isConnected = await printer.isPrinterConnected();
      if (isConnected) {
        _logger.debug('ZSDK connection test successful for $address');
        return printer;
      } else {
        _logger.warning('ZSDK connection test failed for $address');
        return null;
      }
    } catch (e) {
      _logger.error('Failed to create ZSDK connection: $e');
      return null;
    }
  }

  /// Close ZSDK connection
  Future<void> _closeZSDKConnection(ZebraPrinter printer) async {
    try {
      _logger.debug('Closing ZSDK connection');
      // ZebraPrinter handles disconnection internally
      await printer.disconnect();
    } catch (e) {
      _logger.warning('Failed to close ZSDK connection: $e');
    }
  }

  /// Perform ZSDK discovery using ZebraPrinterDiscovery
  Future<List<ZebraDevice>> _performZSDKDiscovery(DiscoveryOptions? options) async {
    try {
      _logger.debug('Performing ZSDK discovery');
      
      // Use ZebraPrinterDiscovery for actual discovery
      final discovery = ZebraPrinterDiscovery();
      
      // Start discovery with options
      final result = await discovery.discoverPrinters(
        timeout: options?.timeout ?? const Duration(seconds: 5),
      );
      
      if (result.success) {
        _logger.debug('ZSDK discovery found ${result.data!.length} devices');
        return result.data!;
      } else {
        _logger.warning('ZSDK discovery failed: ${result.error?.message}');
        return [];
      }
    } catch (e) {
      _logger.error('ZSDK discovery failed: $e');
      return [];
    }
  }

  /// Start periodic health check timer for all pooled connections
  void _startHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _validateAllConnections();
      _cleanupStaleConnections();
    });
  }

  /// Validate all connections in the pool, attempt reconnection if unhealthy
  Future<void> _validateAllConnections() async {
    for (final address in _connectionPool.keys.toList()) {
      final printer = _connectionPool[address]!;
      try {
        final healthy = await printer.isPrinterConnected();
        if (!healthy) {
          _logger.warning('Connection to $address is unhealthy, attempting reconnection');
          final reconnected = await _attemptReconnection(address);
          if (!reconnected) {
            markConnectionUnhealthy(address);
            _logger.warning('Failed to reconnect to $address, removed from pool');
          }
        } else {
          _connectionHealth[address] = true;
        }
      } catch (e) {
        markConnectionUnhealthy(address);
        _logger.error('Error during health check for $address: $e');
      }
    }
  }

  /// Attempt to reconnect to a printer, returns true if successful
  Future<bool> _attemptReconnection(String address) async {
    const maxAttempts = 2;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      _logger.info('Reconnection attempt ${attempt + 1} for $address');
      final result = await connect(address);
      if (result.success) {
        _logger.info('Reconnection to $address successful');
        return true;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    return false;
  }

  /// Remove stale connections from the pool (not used for 10+ minutes)
  void _cleanupStaleConnections() {
    final now = DateTime.now();
    final stale = _connectionTimestamps.entries
        .where((e) => now.difference(e.value) > const Duration(minutes: 10))
        .map((e) => e.key)
        .toList();
    for (final address in stale) {
      _logger.info('Removing stale connection for $address');
      _connectionPool.remove(address);
      _connectionTimestamps.remove(address);
      _connectionHealth.remove(address);
      _connectionFailureCounts.remove(address);
      if (currentAddress == address) {
        isConnected = false;
        currentAddress = null;
      }
    }
  }

  /// Get connection pool status
  Map<String, dynamic> getConnectionPoolStatus() {
    return {
      'poolSize': _connectionPool.length,
      'currentAddress': currentAddress,
      'isConnected': isConnected,
      'connectionTimestamps': Map<String, DateTime>.from(_connectionTimestamps),
      'failureCounts': Map<String, int>.from(_connectionFailureCounts),
      'connectionHealth': Map<String, bool>.from(_connectionHealth),
    };
  }

  /// Get connection health status for all pooled connections
  Map<String, bool> getConnectionHealthStatus() {
    return Map<String, bool>.from(_connectionHealth);
  }

  /// Get detailed health metrics for monitoring
  Map<String, dynamic> getHealthMetrics() {
    final now = DateTime.now();
    final metrics = <String, dynamic>{
      'totalConnections': _connectionPool.length,
      'healthyConnections': _connectionHealth.values.where((h) => h).length,
      'unhealthyConnections': _connectionHealth.values.where((h) => !h).length,
      'currentAddress': currentAddress,
      'isConnected': isConnected,
      'lastDiscoveryTime': _lastDiscoveryTime?.toIso8601String(),
      'discoveredDevicesCount': _lastDiscoveredDevices.length,
    };

    // Add per-connection metrics
    final connectionMetrics = <String, Map<String, dynamic>>{};
    for (final entry in _connectionPool.entries) {
      final address = entry.key;
      final timestamp = _connectionTimestamps[address];
      final failureCount = _connectionFailureCounts[address] ?? 0;
      final isHealthy = _connectionHealth[address] ?? false;
      
      connectionMetrics[address] = {
        'isHealthy': isHealthy,
        'failureCount': failureCount,
        'lastUsed': timestamp?.toIso8601String(),
        'ageMinutes': timestamp != null ? now.difference(timestamp).inMinutes : 0,
      };
    }
    metrics['connectionDetails'] = connectionMetrics;

    return metrics;
  }

  /// Check if a specific connection is healthy
  bool isConnectionHealthy(String address) {
    return _connectionHealth[address] ?? false;
  }

  /// Get connection age in minutes
  int getConnectionAge(String address) {
    final timestamp = _connectionTimestamps[address];
    if (timestamp == null) return -1;
    return DateTime.now().difference(timestamp).inMinutes;
  }

  /// Force health check on a specific connection
  Future<bool> forceHealthCheck(String address) async {
    final printer = _connectionPool[address];
    if (printer == null) return false;

    try {
      final healthy = await printer.isPrinterConnected();
      _connectionHealth[address] = healthy;
      return healthy;
    } catch (e) {
      _logger.error('Force health check failed for $address: $e');
      _connectionHealth[address] = false;
      return false;
    }
  }

  /// Get connection failure statistics
  Map<String, int> getFailureStatistics() {
    return Map<String, int>.from(_connectionFailureCounts);
  }

  /// Reset failure count for a connection
  void resetFailureCount(String address) {
    _connectionFailureCounts.remove(address);
    _logger.info('Reset failure count for $address');
  }

  /// Get pool statistics
  Map<String, dynamic> getPoolStatistics() {
    final now = DateTime.now();
    final activeConnections = _connectionPool.entries
        .where((e) {
          final timestamp = _connectionTimestamps[e.key];
          return timestamp != null && now.difference(timestamp).inMinutes < 10;
        })
        .length;

    return {
      'totalConnections': _connectionPool.length,
      'activeConnections': activeConnections,
      'staleConnections': _connectionPool.length - activeConnections,
      'healthyConnections': _connectionHealth.values.where((h) => h).length,
      'unhealthyConnections': _connectionHealth.values.where((h) => !h).length,
      'totalFailures': _connectionFailureCounts.values.isEmpty ? 0 : _connectionFailureCounts.values.reduce((sum, count) => sum + count),
    };
  }

  /// Dispose resources
  void dispose() {
    _healthCheckTimer?.cancel();
    resetPoolIfNeeded();
  }
} 