import 'dart:async';
import 'dart:io';
import 'package:zebrautil/models/print_enums.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'package:zebrautil/zebra_printer.dart';
import 'package:zebrautil/zebra_sgd_commands.dart';
import 'package:zebrautil/internal/commands/command_factory.dart';

import '../../internal/logger.dart';
import 'managers/connection_manager.dart';
import 'managers/cache_manager.dart';
import 'managers/print_optimizer.dart';
import 'managers/retry_manager.dart';
import 'managers/command_manager.dart';
import 'managers/reliability_manager.dart';
import 'managers/health_manager.dart';
import 'options/smart_print_options.dart';
import 'options/smart_batch_options.dart';
import 'options/connect_options.dart';
import 'options/discovery_options.dart';
import 'models/connection_type.dart';
import 'models/zebra_printer_smart_status.dart';

/// ZSDK-First Smart API for Zebra printers with connection-agnostic optimizations
///
/// This class provides high-performance printing by leveraging ZSDK's built-in optimizations:
/// - ZSDK connection pooling and caching for all device types
/// - iOS 13+ permission handling with MFi compliance
/// - Format detection and optimization using ZSDK's ZebraPrinterFactory
/// - Comprehensive logging and monitoring
/// - Production-ready reliability features with autoPrint parity
class ZebraPrinterSmart {
  // Singleton instance
  static ZebraPrinterSmart? _instance;

  // Core managers
  late final Logger _logger;
  late final ConnectionManager _connectionManager;
  late final CacheManager _cacheManager;
  late final PrintOptimizer _printOptimizer;
  late final RetryManager _retryManager;
  late final CommandManager _commandManager;
  late final ReliabilityManager _reliabilityManager;
  late final HealthManager _healthManager;

  // Internal state
  ZebraPrinter? _printer;
  final Map<String, dynamic> _performanceMetrics = {};
  final Map<String, int> _failureCounts = {};
  final List<String> _operationHistory = [];

  /// Private constructor for singleton pattern
  ZebraPrinterSmart._() {
    _logger = Logger.withPrefix('ZebraPrinterSmart');
    _connectionManager = ConnectionManager(_logger);
    _cacheManager = CacheManager(_logger);
    _connectionManager.setCacheManager(_cacheManager);
    _printOptimizer = PrintOptimizer(_logger);
    _retryManager = RetryManager(_logger);
    _commandManager = CommandManager(_logger);
    _reliabilityManager = ReliabilityManager(_logger, _commandManager);
    _healthManager = HealthManager(_logger);
    _logger.info('ZebraPrinterSmart initialized with ZSDK-first approach');
  }
  
  /// Get singleton instance
  static ZebraPrinterSmart get instance {
    _instance ??= ZebraPrinterSmart._();
    return _instance!;
  }

  /// Main print method - "Just Works" philosophy with ZSDK optimization
  ///
  /// Handles everything automatically:
  /// - iOS optimization and permission handling
  /// - Health checks and self-healing
  /// - Auto-connection with ZSDK connection pooling
  /// - Format detection using ZSDK's ZebraPrinterFactory
  /// - Reliability features with autoPrint parity
  /// - Connection-agnostic optimizations
  Future<Result<void>> print(
    String data, {
    String? address,
    PrintFormat? format,
    SmartPrintOptions? options,
  }) async {
    final startTime = DateTime.now();
    _logger.info('Starting ZSDK-optimized smart print operation');
    
    try {
      // 1. Health check and self-healing
      await _healthManager.performHealthCheck();
      
      // 2. Use provided options or default
      final effectiveOptions = options ?? const SmartPrintOptions();

      // 3. Auto-detect or use provided address
      final targetAddress = address ?? await _autoDetectPrinter();
      if (targetAddress == null) {
        return Result.error('No printer address available', code: ErrorCodes.notConnected);
      }

      // 4. Auto-connect with ZSDK optimization
      final connectionResult = await _ensureConnected(targetAddress, effectiveOptions);
      if (!connectionResult.success) {
        return Result.error(
            'Failed to connect: ${connectionResult.error?.message ?? 'Unknown error'}',
            code: ErrorCodes.connectionError);
      }
      
      // 5. Auto-detect format if not provided using ZSDK
      final detectedFormat = format ?? _detectFormat(data);
      
      // 6. Ensure reliability (autoPrint parity)
      await _reliabilityManager.ensureReliability(detectedFormat, _printer!);

      // 7. Print with ZSDK optimization
      final result = await _printOptimized(data, detectedFormat, effectiveOptions);

      // 8. Update performance metrics
      final duration = DateTime.now().difference(startTime);
      _updatePerformanceMetrics('print', duration, result.success);
      _logger.info('Print operation completed in ${duration.inMilliseconds}ms');

      // 9. Trigger self-healing if needed
      if (!result.success) {
        await _performSelfHealing();
      }

      return result;
    } catch (e, stackTrace) {
      _logger.error('Print operation failed: $e', e, stackTrace);
      _updateFailureCount('print');
      return Result.error('Print operation failed: $e', code: ErrorCodes.printError);
    }
  }
  
  /// Batch print - optimized for multiple labels with ZSDK
  Future<Result<void>> printBatch(
    List<String> data, {
    String? address,
    PrintFormat? format,
    SmartBatchOptions? options,
  }) async {
    final startTime = DateTime.now();
    _logger.info('Starting ZSDK-optimized batch print operation with ${data.length} items');

    try {
      // 1. Auto-detect or use provided address
      final targetAddress = address ?? await _autoDetectPrinter();
      if (targetAddress == null) {
        return Result.error('No printer address available', code: ErrorCodes.notConnected);
      }

      // 2. Auto-connect once for entire batch
      final connectionResult = await _ensureConnected(
          targetAddress, options ?? const SmartPrintOptions());
      if (!connectionResult.success) {
        return Result.error(
            'Failed to connect: ${connectionResult.error?.message ?? 'Unknown error'}',
            code: ErrorCodes.connectionError);
      }

      // 3. Auto-detect format once for entire batch
      final detectedFormat = format ?? _detectFormat(data.first);

      // 4. Optimized batch printing
      final result = await _printBatchOptimized(data, detectedFormat, options);

      final duration = DateTime.now().difference(startTime);
      _updatePerformanceMetrics('batchPrint', duration, result.success);
      _logger.info('Batch print completed in ${duration.inMilliseconds}ms');

      return result;
    } catch (e, stackTrace) {
      _logger.error('Batch print failed: $e', e, stackTrace);
      _updateFailureCount('batchPrint');
      return Result.error('Batch print failed: $e', code: ErrorCodes.printError);
    }
  }

  /// Connect to a specific printer using ZSDK
  Future<Result<void>> connect(String address, {ConnectOptions? options}) async {
    _logger.info('Connecting to printer using ZSDK: $address');
    return await _connectionManager.connect(address, options: options);
  }

  /// Disconnect from current printer
  Future<Result<void>> disconnect() async {
    _logger.info('Disconnecting from printer');
    return await _connectionManager.disconnect();
  }

  /// Discover available printers using ZSDK discovery
  Future<Result<List<ZebraDevice>>> discover({DiscoveryOptions? options}) async {
    _logger.info('Starting ZSDK printer discovery');
    return await _connectionManager.discover(options: options);
  }

  /// Get current status with comprehensive metrics
  Future<ZebraPrinterSmartStatus> getStatus() async {
    return ZebraPrinterSmartStatus(
      isConnected: _connectionManager.isConnected,
      cacheHitRate: _cacheManager.getHitRate(),
      connectionHealth: _healthManager.getConnectionHealth(),
      performanceMetrics: _getPerformanceMetrics(),
      lastOperation: _operationHistory.isNotEmpty ? _operationHistory.last : '',
      failureRate: _calculateFailureRate(),
      averagePrintTime: _calculateAveragePrintTime(),
    );
  }

  // Private helper methods



  /// Auto-detect printer address using ZSDK discovery
  Future<String?> _autoDetectPrinter() async {
    // 1. Check if we have a cached connection
    final cachedAddress = _connectionManager.currentAddress;
    if (cachedAddress != null) {
      return cachedAddress;
    }
    
    // 2. Discover available printers using ZSDK
    final discoveryResult = await _connectionManager.discover();
    if (discoveryResult.success && discoveryResult.data!.isNotEmpty) {
      // Return the first available printer
      return discoveryResult.data!.first.address;
    }
    
    // 3. Fallback to paired Bluetooth printers (iOS-specific)
    if (Platform.isIOS) {
      final pairedPrinters = await _getPairedPrinters();
      if (pairedPrinters.isNotEmpty) {
        return pairedPrinters.first.address;
      }
    }
    
    return null;
  }

  /// Get paired printers (iOS-specific)
  Future<List<ZebraDevice>> _getPairedPrinters() async {
    try {
      // Use ZSDK's Bluetooth discovery for paired devices
      final discoveryResult = await _connectionManager.discover(
        options: const DiscoveryOptions(enableMFiDiscovery: true)
      );
      return discoveryResult.success ? discoveryResult.data! : [];
    } catch (e) {
      _logger.warning('Failed to get paired printers: $e');
      return [];
    }
  }

  /// Ensure connected to printer with ZSDK optimization
  Future<Result<void>> _ensureConnected(
      String address, SmartPrintOptions options) async {
    if (_connectionManager.isConnected &&
        _connectionManager.currentAddress == address && _printer != null) {
      return Result.success();
    }
    
    // Create a new printer instance for the address
    _printer = ZebraPrinter(address);
    
    return await _connectionManager.connect(address,
        options: ConnectOptions(
          enablePooling: options.enableConnectionPooling,
          maxConnections: options.maxConnections,
          healthCheckInterval: options.healthCheckInterval,
          enableReconnection: options.enableReconnection,
          enableMFiOptimization: options.enableMFiOptimization,
        ));
  }

  /// Detect print format from data using ZSDK utilities
  PrintFormat _detectFormat(String data) {
    if (ZebraSGDCommands.isZPLData(data)) {
      return PrintFormat.zpl;
    } else if (ZebraSGDCommands.isCPCLData(data)) {
      return PrintFormat.cpcl;
    } else {
      return PrintFormat.zpl; // Default to ZPL
    }
  }

  /// Detect connection type from address (ZSDK handles the actual connection)
  ConnectionType _detectConnectionType(String address) {
    if (address.contains(':') || address.contains('.')) {
      return ConnectionType.network;
    } else if (address.startsWith('USB') || address.startsWith('usb')) {
      return ConnectionType.usb;
    } else {
      return ConnectionType.bluetooth;
    }
  }

  /// Print with ZSDK optimization
  Future<Result<void>> _printOptimized(
    String data,
    PrintFormat format,
    SmartPrintOptions options,
  ) async {
    // Optimize data for connection type if needed
    final optimizedData = await _printOptimizer.optimizeData(data, format, _detectConnectionType(_connectionManager.currentAddress ?? ''));

    // Execute print with retry logic
    return await _retryManager.executeWithRetry(
      () => _executePrint(optimizedData, format, options),
      maxRetries: options.maxRetries,
      retryDelay: options.retryDelay,
      retryBackoff: options.retryBackoff,
    );
  }
  
  /// Execute actual print operation using ZSDK
  Future<Result<void>> _executePrint(
      String data, PrintFormat format, SmartPrintOptions options) async {
    if (_printer == null) {
      return Result.error('No printer instance available', code: ErrorCodes.notConnected);
    }
    
    // Clear buffer if enabled
    if (options.clearBufferBeforePrint) {
      await _commandManager.executeFormatSpecificCommand(format, 'clearBuffer', _printer!);
    }

    // Send print data using command pattern
    final result = await CommandFactory.createSendCommandCommand(_printer!, data)
        .execute();

    // Flush buffer if enabled
    if (options.flushBufferAfterPrint) {
      await _commandManager.executeFormatSpecificCommand(format, 'flushBuffer', _printer!);
    }

    return result;
  }

  /// Print batch with ZSDK optimization
  Future<Result<void>> _printBatchOptimized(
    List<String> data,
    PrintFormat format,
    SmartBatchOptions? options,
  ) async {
          final batchOptions = options ?? const SmartBatchOptions.reliable();

    if (batchOptions.parallelProcessing) {
      // Parallel processing for network printers
      final futures = data.map((item) =>
          _printOptimized(item, format, batchOptions));
      final results = await Future.wait(futures);

      // Check if any failed
      final failures = results.where((r) => !r.success).toList();
      if (failures.isNotEmpty) {
        return Result.error(
            'Batch print failed: ${failures.first.error?.message ?? 'Unknown error'}',
            code: ErrorCodes.printError);
      }

      return Result.success();
    } else {
      // Sequential processing for reliability
      for (final item in data) {
        final result = await _printOptimized(item, format, batchOptions);
        if (!result.success) {
          return result;
        }

        // Add delay between prints if specified
        if (batchOptions.batchDelay.inMilliseconds > 0) {
          await Future.delayed(batchOptions.batchDelay);
        }
      }

      return Result.success();
    }
  }

  /// Perform self-healing with ZSDK optimization
  Future<void> _performSelfHealing() async {
    _logger.warning('Performing self-healing with ZSDK optimization');

    // Clear corrupted cache
    await _cacheManager.clearCorrupted();

    // Reset connection pool if needed
    await _connectionManager.resetPoolIfNeeded();

    // Recalibrate performance baselines
    _recalibratePerformanceBaselines();
  }

  /// Update performance metrics
  void _updatePerformanceMetrics(String operation, Duration duration, bool success) {
    final key = '${operation}_${DateTime.now().millisecondsSinceEpoch ~/ 60000}'; // Minute-based key
    
    if (!_performanceMetrics.containsKey(key)) {
      _performanceMetrics[key] = {
        'count': 0,
        'totalTime': 0,
        'successCount': 0,
      };
    }
    
    final metrics = _performanceMetrics[key] as Map<String, dynamic>;
    metrics['count'] = (metrics['count'] as int) + 1;
    metrics['totalTime'] = (metrics['totalTime'] as int) + duration.inMilliseconds;
    if (success) {
      metrics['successCount'] = (metrics['successCount'] as int) + 1;
    }
    
    // Keep only last 60 minutes of metrics
    final cutoff = DateTime.now().millisecondsSinceEpoch - 3600000;
    _performanceMetrics.removeWhere((key, value) {
      final parts = key.split('_');
      if (parts.length < 2) return false;
      final timestamp = int.tryParse(parts[1]) ?? 0;
      return timestamp < cutoff;
    });
    
    _operationHistory.add('$operation: ${duration.inMilliseconds}ms');
    if (_operationHistory.length > 100) {
      _operationHistory.removeAt(0);
    }
  }

  /// Update failure count
  void _updateFailureCount(String operation) {
    _failureCounts[operation] = (_failureCounts[operation] ?? 0) + 1;
  }

  /// Get performance metrics
  Map<String, dynamic> _getPerformanceMetrics() {
    if (_performanceMetrics.isEmpty) {
      return {
        'averagePrintTime': 0,
        'successRate': 1.0,
        'cacheHitRate': _cacheManager.getHitRate(),
        'connectionHealth': _healthManager.getConnectionHealth(),
        'totalOperations': 0,
      };
    }
    
    int totalCount = 0;
    int totalTime = 0;
    int totalSuccess = 0;
    
    for (final metrics in _performanceMetrics.values) {
      final map = metrics as Map<String, dynamic>;
      totalCount += (map['count'] as int?) ?? 0;
      totalTime += (map['totalTime'] as int?) ?? 0;
      totalSuccess += (map['successCount'] as int?) ?? 0;
    }
    
    return {
      'averagePrintTime': totalCount > 0 ? totalTime ~/ totalCount : 0,
      'successRate': totalCount > 0 ? totalSuccess / totalCount : 1.0,
      'cacheHitRate': _cacheManager.getHitRate(),
      'connectionHealth': _healthManager.getConnectionHealth(),
      'totalOperations': totalCount,
    };
  }

  /// Calculate failure rate
  double _calculateFailureRate() {
    final totalFailures = _failureCounts.values.fold<int>(0, (sum, count) => sum + count);
    final totalOperations = _performanceMetrics.values.fold<int>(0, (sum, metrics) {
      final map = metrics as Map<String, dynamic>;
      return sum + (map['count'] as int? ?? 0);
    });
    
    return totalOperations > 0 ? totalFailures / totalOperations : 0.0;
  }

  /// Calculate average print time
  int _calculateAveragePrintTime() {
    if (_performanceMetrics.isEmpty) return 0;
    
    int totalTime = 0;
    int totalCount = 0;
    
    for (final metrics in _performanceMetrics.values) {
      final map = metrics as Map<String, dynamic>;
      totalTime += (map['totalTime'] as int?) ?? 0;
      totalCount += (map['count'] as int?) ?? 0;
    }
    
    return totalCount > 0 ? totalTime ~/ totalCount : 0;
  }

  /// Recalibrate performance baselines
  void _recalibratePerformanceBaselines() {
    _logger.info('Recalibrating performance baselines');
    // Clear old metrics to start fresh
    _performanceMetrics.clear();
    _failureCounts.clear();
  }
} 