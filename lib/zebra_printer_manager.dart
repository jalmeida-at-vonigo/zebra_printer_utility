import 'dart:async';

import 'package:flutter/services.dart';

import 'internal/commands/command_factory.dart';
import 'internal/communication_policy.dart';
import 'internal/logger.dart';
import 'internal/printer_preferences.dart';
import 'internal/smart_device_selector.dart';
import 'models/communication_policy_options.dart';
import 'models/print_enums.dart';
import 'models/print_operation_tracker.dart';
import 'models/print_options.dart';
import 'models/result.dart';
import 'models/zebra_device.dart';
import 'zebra_printer.dart';
import 'zebra_printer_discovery.dart';
import 'zebra_printer_readiness_manager.dart';
import 'zebra_sgd_commands.dart';

/// Simple cancellation token for status polling
class CancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}



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
  ZebraPrinterReadinessManager? _readinessManager;
  CommunicationPolicy? _communicationPolicy;

  StreamController<ZebraDevice?>? _connectionStreamController;
  StreamController<String>? _statusStreamController;
  final Logger _logger = Logger.withPrefix('ZebraPrinterManager');

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
  Future<Result<bool>> initialize() async {
    try {
      _logger.info('Initializing ZebraPrinterManager');
      
      // Initialize controller and streams
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
      _readinessManager = ZebraPrinterReadinessManager(printer: _printer!);
      
      // Initialize communication policy with status updates
      _communicationPolicy = CommunicationPolicy(
        _printer!,
        onStatusUpdate: (status) {
          _statusStreamController?.add(status);
        },
      );
      
      _logger.info('ZebraPrinterManager initialization completed');
      return Result.success(true);
    } catch (e) {
      _logger.error('Failed to initialize ZebraPrinterManager: $e');
      return Result.error('Initialization failed: $e');
    }
  }

  void _onControllerChanged() {
    _connectionStreamController?.add(connectedPrinter);
  }

  // ===== PRIMITIVE OPERATIONS =====
  // These methods provide direct access to printer primitives
  // No workflow logic, just method forwarding with basic error handling

  /// Primitive: Connect to a printer by address or device
  Future<Result<void>> connect(
    dynamic printerIdentifier, {
    CommunicationPolicyOptions? options,
  }) async {
    String? address;
    ZebraDevice? device;
    options ??= const CommunicationPolicyOptions();
    options = options
        .mergeWith(const CommunicationPolicyOptions(skipConnectionCheck: true));

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

    // Use CommunicationPolicy for connection with retry logic
    return await _communicationPolicy!.execute(
      () async {
        _statusStreamController?.add('Connecting to $address...');
        final result = await _printer!.connectToPrinter(address!);

        if (result.success) {
          _logger.info('Manager: Successfully connected to printer: $address');
          _statusStreamController?.add('Connected to $address');

          // Record successful connection for smart selection
          await SmartDeviceSelector.recordSuccessfulConnection(address);

          // Use the provided device or find it in the controller's list
          final ZebraDevice? deviceToSave = device ??
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
      },
      'Connect to Printer',
      options: options,
    );
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
  Future<Result<PrintOperationTracker>> print(String data,
      {PrintOptions? options}) async {
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
      // Step 1: Ensure connection health before printing (skip if called from SmartPrintManager)
      final skipConnectionCheck = options?.skipConnectionHealthCheck ?? false;
      if (!skipConnectionCheck) {
        _logger.info('Manager: Ensuring connection health before printing');
        _logger.debug(
            'Manager: Connection health check triggered by ZebraPrinterManager.print() - this may be redundant if called from SmartPrintManager');
        
        final healthResult = await _communicationPolicy!.getConnectionStatus();
        if (!healthResult.success || !healthResult.data!) {
          _logger.warning(
              'Manager: Connection health check failed, attempting reconnection');
          final reconnectResult = await connect(
            connectedPrinter!,
            options: CommunicationPolicyOptions(
              skipConnectionRetry: true,
              cancellationToken: options?.cancellationToken,
            ),
          );

          if (!reconnectResult.success) {
            _logger.error(
                'Manager: Failed to reconnect after connection health failure');
            return Result.error('Failed to establish connection for printing');
          }
        } else {
          _logger.debug(
              'Manager: Connection health check passed - printer is ready for printing');
        }
      } else {
        _logger.debug(
            'Manager: Skipping connection health check (already handled by SmartPrintManager)');
      }

      // Step 2: Detect data format
      options = PrintOptions.defaults().copyWith(options);
      final detectedFormat = options.formatOrDefault ??
          ZebraSGDCommands.detectDataLanguage(data) ??
          PrintFormat.zpl;
      _logger.info('Manager: Detected print format: ${detectedFormat.name}');

      // Step 3: Prepare printer for printing (integrated prepareForPrint)
      _logger.info(
          'Manager: Preparing printer for ${detectedFormat.name} printing');
      _statusStreamController?.add('Preparing printer...');

      final readinessOptions = options.readinessOptionsOrDefault;

      final prepareResult = await _readinessManager!.prepareForPrint(
        detectedFormat,
        readinessOptions,
        cancellationToken: options.cancellationToken,
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

      // Check for cancellation after readiness preparation
      if (options.cancellationToken?.isCancelled ?? false) {
        _logger.info(
            'Print operation cancelled by user after readiness preparation');
        return Result.errorCode(
          ErrorCodes.operationCancelled,
          formatArgs: ['Print operation cancelled'],
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

      // Step 4: Prepare data based on format
      final preparedData = _preparePrintData(data, detectedFormat);

      // Step 5: Send print data with connection failure handling
      _logger.info('Manager: Sending print data to printer');
      _statusStreamController?.add('Sending print data...');

      // Check for cancellation before sending print data
      if (options.cancellationToken?.isCancelled ?? false) {
        _logger.info('Print operation cancelled by user before sending data');
        return Result.errorCode(
          ErrorCodes.operationCancelled,
          formatArgs: ['Print operation cancelled'],
        );
      }

      final printResult = await _communicationPolicy!.execute(
        () => _printer!.print(data: preparedData, format: detectedFormat),
        'Send Print Data',
        options: CommunicationPolicyOptions(
          maxAttempts: 3,
          skipConnectionCheck: false,
          skipConnectionRetry: false,
          cancellationToken: options.cancellationToken,
          onEvent: (event) {
            // Forward status updates to the status stream
            _statusStreamController?.add(event.message);
          },
        ),
      );
      
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

      // Get the tracker from the print result
      final tracker = printResult.data;
      if (tracker != null) {
        _logger.info(
            'Manager: Received tracker from print operation: ${tracker.operationId}');
      }

      _logger.info('Manager: Print data sent successfully');
      _statusStreamController?.add('Print data sent successfully');

      // Step 6: Post-print buffer operations (format-specific)
      if (detectedFormat == PrintFormat.cpcl) {
        // Check for cancellation before buffer operations
        if (options.cancellationToken?.isCancelled ?? false) {
          _logger.info(
              'Print operation cancelled by user before buffer operations');
          return Result.errorCode(
            ErrorCodes.operationCancelled,
            formatArgs: ['Print operation cancelled'],
          );
        }
        
        _logger.info('Manager: Sending CPCL flush command');
        try {
          final flushCommand =
              CommandFactory.createSendCpclFlushBufferCommand(_printer!);
          final flushResult = await _communicationPolicy!.execute(
            () => flushCommand.execute(),
            flushCommand.operationName,
            options: CommunicationPolicyOptions(
              skipConnectionCheck: true, // We just printed successfully
              skipConnectionRetry: true, // This is optional cleanup
              maxAttempts: 1,
              cancellationToken: options.cancellationToken,
            ),
          );
          if (flushResult.success) {
            await Future.delayed(const Duration(milliseconds: 100));
            _logger.info('Manager: CPCL buffer flushed successfully');
          } else {
            _logger.warning(
                'Manager: CPCL buffer flush failed: ${flushResult.error?.message}');
          }
        } catch (e) {
          _logger.warning('Manager: CPCL buffer flush failed: $e');
        }
      }

      // Step 7: Wait for print completion with format-specific delays (if enabled)
      if (options.waitForPrintCompletionOrDefault && tracker != null) {
        // Check for cancellation before waiting for completion
        if (options.cancellationToken?.isCancelled ?? false) {
          _logger.info(
              'Manager: Print operation cancelled before completion wait');
          return Result.errorCode(
            ErrorCodes.operationCancelled,
            formatArgs: ['Print operation cancelled'],
          );
        }
        
        final completionResult = await tracker.waitForCompletion(
          data: preparedData,
          format: detectedFormat,
          onStatusUpdate: (status) => _statusStreamController?.add(status),
        );
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
            _statusStreamController
                ?.add('Print completed with hardware issues');
          }
        }
      } else {
        _logger.info('Manager: Skipping print completion wait (disabled)');
        _statusStreamController
            ?.add('Print data sent (completion wait disabled)');
      }

      return Result.success(tracker);
    } catch (e, stack) {
      _logger.error(
          'Manager: Unexpected error during print operation', e, stack);
      _statusStreamController?.add('Print error: $e');
      return Result.errorCode(
        ErrorCodes.printError,
        formatArgs: ['Unexpected print error: $e'],
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
      final result = await _communicationPolicy!.execute(
        () => statusCommand.execute(),
        statusCommand.operationName,
        options: const CommunicationPolicyOptions(
          skipConnectionCheck: false,
          skipConnectionRetry: false,
          maxAttempts: 2,
        ),
      );

      if (result.success) {
        _logger.info('Manager: Printer status retrieved successfully');
        return result;
      } else {
        _logger.error(
            'Manager: Failed to get printer status - ${result.error!.message}');
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
      final result = await _communicationPolicy!.execute(
        () => statusCommand.execute(),
        statusCommand.operationName,
        options: const CommunicationPolicyOptions(
          skipConnectionCheck: false,
          skipConnectionRetry: false,
          maxAttempts: 2,
        ),
      );

      if (result.success) {
        _logger.info('Manager: Detailed printer status retrieved successfully');
        return result;
      } else {
        _logger.error(
            'Manager: Failed to get detailed printer status - ${result.error!.message}');
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
    final result = await _printer!.isPrinterConnected();
    return result.success ? (result.data ?? false) : false;
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
    
    // Close stream controllers safely
    _connectionStreamController?.close();
    _connectionStreamController = null;
    _statusStreamController?.close();
    _statusStreamController = null;
  }
}
