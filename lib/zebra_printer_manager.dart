import 'dart:async';
import 'package:flutter/services.dart';
import 'package:zebrautil/zebrautil.dart';
import 'internal/commands/command_factory.dart';
import 'internal/smart_device_selector.dart';
import 'internal/printer_preferences.dart';
import 'internal/logger.dart';

/// Manager for Zebra printer instances and state
///
/// This manager is responsible for:
/// - Creating and managing ZebraPrinter instances
/// - Managing connection state and streams
/// - Providing access to printer primitives
/// - Coordinating discovery and connection state
/// - Providing robust print operations with integrated workflow
///
/// It does NOT contain workflow logic - that belongs in SmartPrintManager
/// and other workflow managers.
class ZebraPrinterManager {
  ZebraPrinter? _printer;
  ZebraController? _controller;
  ZebraPrinterDiscovery? _discovery;
  PrinterReadinessManager? _readinessManager;

  StreamController<ZebraDevice?>? _connectionStreamController;
  StreamController<String>? _statusStreamController;
  final Logger _logger = Logger.withPrefix('ZebraPrinterManager');

  // Smart print manager instance

  /// Public getter for the underlying ZebraPrinter instance
  ZebraPrinter? get printer => _printer;

  /// Public getter for the status stream controller
  StreamController<String>? get statusStreamController =>
      _statusStreamController;

  /// Stream of current connection state
  Stream<ZebraDevice?> get connection =>
      _connectionStreamController?.stream ?? const Stream.empty();

  /// Stream of status messages
  Stream<String> get status =>
      _statusStreamController?.stream ?? const Stream.empty();

  /// Currently connected printer
  ZebraDevice? get connectedPrinter {
    if (_controller == null) return null;
    final connected =
        _controller!.printers.where((p) => p.isConnected).firstOrNull;
    return connected;
  }

  /// Discovery service for printer scanning and discovery
  ZebraPrinterDiscovery get discovery => _discovery ??= ZebraPrinterDiscovery();

  /// List of discovered printers
  List<ZebraDevice> get discoveredPrinters => _controller?.printers ?? [];

  /// Initialize the printer manager
  Future<void> initialize() async {
    if (_printer != null) return;

    _logger.info('Initializing ZebraPrinterManager');
    _controller = ZebraController();
    _connectionStreamController = StreamController<ZebraDevice?>.broadcast();
    _statusStreamController = StreamController<String>.broadcast();

    // Initialize discovery service
    _logger.info('Initializing discovery service');
    await discovery.initialize(
      controller: _controller,
      statusCallback: (msg) => _statusStreamController?.add(msg),
    );

    // Listen to controller changes for connection updates
    _controller!.addListener(_onControllerChanged);

    _logger.info('Creating printer instance');
    _printer = await _getPrinterInstance(
      controller: _controller,
      onDiscoveryError: (code, message) {
        _logger.error('Discovery error: $code - $message');
        _statusStreamController?.add('Discovery error: $message');
      },
      onPermissionDenied: () {
        _logger.warning(
            'Bluetooth permission denied, continuing with network discovery only');
        _statusStreamController
            ?.add('Bluetooth permission denied, using network discovery');
      },
    );

    // Initialize readiness manager
    _readinessManager = PrinterReadinessManager(printer: _printer!);

    _logger.info('ZebraPrinterManager initialization completed');
  }

  void _onControllerChanged() {
    _connectionStreamController?.add(connectedPrinter);
  }

  // ===== PRIMITIVE OPERATIONS =====
  // These methods provide direct access to printer primitives
  // No workflow logic, just method forwarding with basic error handling

  /// Primitive: Connect to a printer by address or device
  Future<Result<void>> connect(dynamic printerIdentifier) async {
    String? address;
    ZebraDevice? device;

    if (printerIdentifier is ZebraDevice) {
      device = printerIdentifier;
      address = device.address;
    } else if (printerIdentifier is String) {
      address = printerIdentifier;
    } else {
      address = connectedPrinter?.address;
    }

    _logger.info('Manager: Connecting to printer: $address');
    await _ensureInitialized();

    try {
      _statusStreamController?.add('Connecting to $address...');
      final result = await _printer!.connectToPrinter(address!);

      if (result.success) {
        _logger.info('Manager: Successfully connected to printer: $address');
        _statusStreamController?.add('Connected to $address');

        // Record successful connection for smart selection
        await SmartDeviceSelector.recordSuccessfulConnection(address);

        // Use the provided device or find it in the controller's list
        ZebraDevice? deviceToSave = device ??
            _controller?.printers.firstWhere(
              (p) => p.address == address,
              orElse: () => ZebraDevice(
                  address: address ?? '',
                  name: 'Unknown Printer',
                  status: 'Connected',
                  isWifi: (address ?? '').contains('.')),
            );

        if (deviceToSave != null) {
          await PrinterPreferences.saveLastSelectedPrinter(deviceToSave);
        }

        return result;
      } else {
        _logger.error(
            'Manager: Failed to connect to printer: $address - ${result.error?.message}');
        _statusStreamController?.add('Failed to connect to $address');

        // Record failed connection
        await SmartDeviceSelector.recordFailedConnection(address);

        return result;
      }
    } catch (e, stack) {
      _logger.error('Manager: Connection error to printer: $address', e, stack);
      _statusStreamController?.add('Connection error: $e');
      if (e.toString().contains('timeout')) {
        return Result.errorCode(
          ErrorCodes.connectionTimeout,
          dartStackTrace: stack,
        );
      }
      return Result.errorCode(
        ErrorCodes.connectionError,
        formatArgs: ['Connection error: $e'],
        dartStackTrace: stack,
      );
    }
  }

  /// Primitive: Disconnect from current printer
  Future<Result<void>> disconnect() async {
    _logger.info('Manager: Disconnecting from printer');
    await _ensureInitialized();

    if (connectedPrinter != null) {
      try {
        _statusStreamController?.add('Disconnecting...');
        final result = await _printer!.disconnect();
        _logger.info('Manager: Printer disconnected successfully');
        _statusStreamController?.add('Disconnected');
        return result;
      } catch (e, stack) {
        _logger.error('Manager: Disconnect error', e, stack);
        _statusStreamController?.add('Disconnect error: $e');
        return Result.errorCode(
          ErrorCodes.connectionError,
          formatArgs: ['Failed to disconnect: $e'],
          dartStackTrace: stack,
        );
      }
    }
    _logger.info('Manager: No printer connected to disconnect');
    return Result.success();
  }

  /// Prepare print data based on format detection
  /// This handles CPCL line endings, PRINT command addition, and other format-specific preparation
  String _preparePrintData(String data, PrintFormat? format) {
    // Use provided format or detect from data
    final detectedFormat = format ?? ZebraSGDCommands.detectDataLanguage(data);
    final isCPCL = detectedFormat == PrintFormat.cpcl;

    _logger.info(
        'Preparing print data - detected format: ${detectedFormat?.name ?? 'unknown'}, isCPCL: $isCPCL');

    if (isCPCL) {
      _logger.info('Preparing CPCL data with proper line endings and commands');

      // 1. For CPCL, ensure proper line endings - convert any \n to \r\n for CPCL
      String preparedData = data.replaceAll(RegExp(r'(?<!\r)\n'), '\r\n');

      // 2. Check if CPCL data ends with FORM but missing PRINT
      if (preparedData.trim().endsWith('FORM') &&
          !preparedData.contains('PRINT')) {
        _logger.warning('CPCL data missing PRINT command, adding it');
        preparedData = '${preparedData.trim()}\r\nPRINT\r\n';
      }

      // 3. Ensure CPCL ends with proper line endings for buffer flush
      if (!preparedData.endsWith('\r\n')) {
        preparedData += '\r\n';
      }

      // 4. Add extra line feeds to ensure complete transmission
      preparedData += '\r\n\r\n';

      _logger.info(
          'CPCL data prepared - original: ${data.length} chars, prepared: ${preparedData.length} chars');
      return preparedData;
    } else {
      _logger.info('Using ZPL or other format, data prepared as-is');
      return data;
    }
  }

  /// Robust print method with integrated workflow - as robust as the old ZebraPrinterService
  /// This combines pre-print preparation, print execution, and post-print verification
  Future<Result<void>> print(String data, {PrintFormat? format}) async {
    _logger.info('Manager: Starting robust print operation');
    await _ensureInitialized();

    if (connectedPrinter == null) {
      _logger.error('Manager: Print operation failed - No printer connected');
      _statusStreamController?.add('No printer connected');
      return Result.errorCode(
        ErrorCodes.notConnected,
      );
    }

    try {
      // Step 1: Detect data format
      final detectedFormat = format ??
          ZebraSGDCommands.detectDataLanguage(data) ??
          PrintFormat.zpl;
      _logger.info('Manager: Detected print format: ${detectedFormat.name}');

      // Step 2: Prepare printer for printing (integrated prepareForPrint)
      _logger.info(
          'Manager: Preparing printer for ${detectedFormat.name} printing');
      _statusStreamController?.add('Preparing printer...');

      final readinessOptions = ReadinessOptions.quickWithLanguage();

      final prepareResult = await _readinessManager!.prepareForPrint(
        detectedFormat,
        readinessOptions,
      );

      if (!prepareResult.success) {
        _logger.error(
            'Manager: Printer preparation failed: ${prepareResult.error?.message}');
        _statusStreamController?.add('Printer preparation failed');
        return Result.errorCode(
          ErrorCodes.operationError,
          formatArgs: [
            'Printer preparation failed: ${prepareResult.error?.message}'
          ],
        );
      }

      final readiness = prepareResult.data!;
      if (!readiness.isReady) {
        _logger.warning(
            'Manager: Printer not fully ready after preparation: ${readiness.summary}');
        _statusStreamController
            ?.add('Printer prepared with warnings: ${readiness.summary}');
      } else {
        _logger.info('Manager: Printer prepared successfully');
        _statusStreamController?.add('Printer ready for printing');
      }

      // Step 3: Prepare data based on format
      final preparedData = _preparePrintData(data, format);

      // Step 4: Send print data
      _logger.info('Manager: Sending print data to printer');
      _statusStreamController?.add('Sending print data...');

      final printResult = await _printer!.print(data: preparedData);
      if (!printResult.success) {
        _logger.error(
            'Manager: Print operation failed: ${printResult.error?.message}');
        _statusStreamController
            ?.add('Print failed: ${printResult.error?.message}');
        return Result.errorCode(
          ErrorCodes.printError,
          formatArgs: [printResult.error?.message ?? 'Unknown print error'],
        );
      }

      _logger.info('Manager: Print data sent successfully');
      _statusStreamController?.add('Print data sent successfully');

      // Step 5: Post-print buffer operations (format-specific)
      if (detectedFormat == PrintFormat.cpcl) {
        _logger.info('Manager: Sending CPCL flush command');
        try {
          await CommandFactory.createSendCpclFlushBufferCommand(_printer!)
              .execute();
          await Future.delayed(const Duration(milliseconds: 100));
          _logger.info('Manager: CPCL buffer flushed successfully');
        } catch (e) {
          _logger.warning('Manager: CPCL buffer flush failed: $e');
        }
      }

      // Step 6: Wait for print completion with format-specific delays
      final completionResult =
          await _waitForPrintCompletion(data, detectedFormat);
      if (!completionResult.success) {
        _logger.warning(
            'Manager: Print completion verification failed: ${completionResult.error?.message}');
        _statusStreamController?.add('Print completed (verification failed)');
      } else {
        final success = completionResult.data ?? false;
        if (success) {
          _logger.info('Manager: Print completion verified successfully');
          _statusStreamController?.add('Print completed successfully');
        } else {
          _logger.warning(
              'Manager: Print completion failed - hardware issues detected');
          _statusStreamController?.add('Print completed with hardware issues');
        }
      }

      return Result.success();
    } catch (e, stack) {
      _logger.error('Manager: Print operation error', e, stack);
      _statusStreamController?.add('Print error: $e');
      if (e.toString().contains('timeout')) {
        return Result.errorCode(
          ErrorCodes.operationTimeout,
          dartStackTrace: stack,
        );
      }
      return Result.errorCode(
        ErrorCodes.printError,
        formatArgs: ['Print error: $e'],
        dartStackTrace: stack,
      );
    }
  }

  /// Wait for print completion with format-specific delays and verification
  Future<Result<bool>> _waitForPrintCompletion(
      String data, PrintFormat? format) async {
    try {
      // Calculate delay based on data size and format (same as old service)
      final dataLength = data.length;
      final baseDelay = format == PrintFormat.cpcl ? 2500 : 2000;
      final sizeMultiplier = (dataLength / 1000).ceil(); // Extra 1s per KB
      final effectiveDelay =
          Duration(milliseconds: baseDelay + (sizeMultiplier * 1000));

      _logger.info(
          'Manager: Waiting ${effectiveDelay.inMilliseconds}ms for print completion (data size: $dataLength bytes)');
      _statusStreamController?.add('Waiting for print completion...');

      // Wait for the calculated delay
      await Future.delayed(effectiveDelay); 
      return Result.success(true);
    } catch (e, stack) {
      _logger.error(
          'Manager: Error during print completion verification', e, stack);
      return Result.errorCode(
        ErrorCodes.operationError,
        formatArgs: ['Print completion verification error: $e'],
        dartStackTrace: stack,
      );
    }
  }



  /// Primitive: Get printer status
  Future<Result<Map<String, dynamic>>> getPrinterStatus() async {
    _logger.info('Manager: Getting printer status');
    await _ensureInitialized();

    try {
      if (_printer == null) {
        return Result.errorCode(
          ErrorCodes.notConnected,
        );
      }

      final statusCommand =
          CommandFactory.createGetPrinterStatusCommand(_printer!);
      final result = await statusCommand.execute();

      if (result.success) {
        _logger.info('Manager: Printer status retrieved successfully');
        return result;
      } else {
        _logger.error(
            'Manager: Failed to get printer status - ${result.error?.message}');
        return result;
      }
    } catch (e, stack) {
      _logger.error('Manager: Error getting printer status', e, stack);
      return Result.errorCode(
        ErrorCodes.operationError,
        formatArgs: ['Error getting printer status: $e'],
        dartStackTrace: stack,
      );
    }
  }

  /// Primitive: Get detailed printer status with recommendations
  Future<Result<Map<String, dynamic>>> getDetailedPrinterStatus() async {
    _logger.info('Manager: Getting detailed printer status');
    await _ensureInitialized();

    try {
      if (_printer == null) {
        return Result.errorCode(
          ErrorCodes.notConnected,
        );
      }

      final statusCommand =
          CommandFactory.createGetDetailedPrinterStatusCommand(_printer!);
      final result = await statusCommand.execute();

      if (result.success) {
        _logger.info('Manager: Detailed printer status retrieved successfully');
        return result;
      } else {
        _logger.error(
            'Manager: Failed to get detailed printer status - ${result.error?.message}');
        return result;
      }
    } catch (e, stack) {
      _logger.error('Manager: Error getting detailed printer status', e, stack);
      return Result.errorCode(
        ErrorCodes.operationError,
        formatArgs: ['Error getting detailed printer status: $e'],
        dartStackTrace: stack,
      );
    }
  }

  /// Primitive: Check if a printer is currently connected
  Future<bool> isConnected() async {
    await _ensureInitialized();
    return await _printer!.isPrinterConnected();
  }

  /// Primitive: Rotate print orientation
  void rotate() {
    _printer?.rotate();
  }

  // ===== INTERNAL HELPER METHODS =====

  /// Ensure the manager is initialized
  Future<void> _ensureInitialized() async {
    if (_printer == null) {
      await initialize();
    }
  }

  /// Create a new printer instance
  static Future<ZebraPrinter> _getPrinterInstance({
    ZebraController? controller,
    Function(String code, String? message)? onDiscoveryError,
    Function()? onPermissionDenied,
  }) async {
    const platform = MethodChannel('zebrautil');

    // Get instance ID from platform - iOS returns a String UUID
    final String instanceId =
        await platform.invokeMethod<String>('getInstance') ?? 'default';

    // Return new printer instance
    return ZebraPrinter(
      instanceId,
      controller: controller,
      onDiscoveryError: onDiscoveryError,
      onPermissionDenied: onPermissionDenied,
    );
  }

  /// Dispose of resources
  void dispose() {
    _printer?.dispose();
    _discovery?.dispose();
    _readinessManager = null;
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _connectionStreamController?.close();
    _statusStreamController?.close();
  }
}
