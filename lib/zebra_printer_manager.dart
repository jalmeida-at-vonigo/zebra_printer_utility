import 'dart:async';

import 'internal/commands/command_factory.dart';
import 'internal/communication_policy.dart';
import 'internal/logger.dart';
import 'internal/print_data_detector.dart';
import 'internal/print_data_formatter.dart';
import 'internal/printer_preferences.dart';
import 'internal/smart_device_selector.dart';
import 'internal/zebra_error_bridge.dart';
import 'models/communication_policy_options.dart';
import 'models/connection_event.dart';
import 'models/print_enums.dart';
import 'models/print_operation_tracker.dart';
import 'models/print_options.dart';
import 'models/result.dart';
import 'models/zebra_device.dart';
import 'zebra_printer.dart';
import 'zebra_printer_discovery.dart';
import 'zebra_printer_readiness_manager.dart';

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
  ZebraPrinterManager({
    required ZebraPrinter printer,
  }) : _printer = printer;

  final ZebraPrinter _printer;
  ZebraController? _controller;
  ZebraPrinterDiscovery? _discovery;
  ZebraPrinterReadinessManager? _readinessManager;
  CommunicationPolicy? _communicationPolicy;

  StreamController<ZebraDevice?>? _connectionStreamController;
  StreamController<String>? _statusStreamController;
  final Logger _logger = Logger.withPrefix('ZebraPrinterManager');

  /// Public getter for the underlying ZebraPrinter instance
  ZebraPrinter get printer => _printer;
  
  /// Public getter for the communication policy
  CommunicationPolicy? get communicationPolicy => _communicationPolicy;

  /// Public getter for the status stream controller
  StreamController<String>? get statusStreamController =>
      _statusStreamController;

  /// Stream of current connection state
  Stream<ZebraDevice?> get connection =>
      _connectionStreamController?.stream ?? const Stream.empty();

  /// Stream of status messages
  Stream<String> get status =>
      _statusStreamController?.stream ?? const Stream.empty();

  /// Stream of real-time connection events for immediate UI updates
  Stream<ConnectionEvent> get connectionEvents => _printer.connectionEvents;

  /// Currently connected printer
  ZebraDevice? get connectedPrinter {
    if (_controller == null) return null;
    final connected =
        _controller!.printers.where((p) => p.isConnected).firstOrNull;
    return connected;
  }

  /// Discovery service for printer scanning and discovery
  ZebraPrinterDiscovery get discovery => _discovery ??= ZebraPrinterDiscovery(
        printer: _printer,
      );

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

      // Initialize communication policy with status updates
      _communicationPolicy = CommunicationPolicy(
        _printer,
        onStatusUpdate: (status) {
          _statusStreamController?.add(status);
        },
      );

      // Initialize readiness manager with shared communication policy
      _readinessManager = ZebraPrinterReadinessManager(
        printer: _printer,
        communicationPolicy: _communicationPolicy!,
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
        final result = await _printer.connectToPrinter(address!);

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
        final result = await _printer.disconnect();
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

  /// Prepare print data using the focused PrintDataFormatter
  String _preparePrintData(String data, PrintFormat? format) {
    final formattedData = PrintDataFormatter.formatPrintData(data, format);
    
    // Log formatting details for debugging
    final info =
        PrintDataFormatter.getFormattingInfo(data, formattedData, format);
    _logger.info('Print data formatting - $info');
    
    return formattedData;
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
      // Step 1: Optimistic connection handling (skip if called from SmartPrintManager)
      final skipConnectionCheck = options?.skipConnectionHealthCheck ?? false;
      if (!skipConnectionCheck) {
        _logger.info(
            'Manager: Performing optimistic connection handling before printing');
        
        // Check cached connection state first (no round-trip)
        final cachedConnected = _printer.isPrinterConnectedCached;

        if (cachedConnected == false) {
          // We know we're disconnected, try to reconnect proactively
          _logger.info(
              'Manager: Cached state shows disconnected, attempting proactive reconnection');
          final reconnectResult = await connect(
            connectedPrinter!,
            options: CommunicationPolicyOptions(
              skipConnectionRetry: true,
              cancellationToken: options?.cancellationToken,
            ),
          );

          if (!reconnectResult.success) {
            _logger.error(
                'Manager: Failed to reconnect after detecting disconnected state');
            return Result.error('Failed to establish connection for printing');
          }
        } else if (cachedConnected == null) {
          // Unknown state, proceed optimistically and handle errors if they occur
          _logger.info(
              'Manager: Connection state unknown, proceeding optimistically');
        } else {
          // cachedConnected == true, proceed optimistically
          _logger.debug(
              'Manager: Cached state shows connected, proceeding optimistically');
        }
      } else {
        _logger.debug(
            'Manager: Skipping connection handling (already handled by SmartPrintManager)');
      }

      // Step 2: Detect data format
      options = PrintOptions.defaults().copyWith(options);
      final detectedFormat = options.formatOrDefault ??
          PrintDataDetector.detectFormat(data) ??
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

      // Attempt the print operation optimistically
      var printResult = await _communicationPolicy!.execute(
        () => _printer.print(data: preparedData, format: detectedFormat),
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
      
      // Handle connection errors with automatic reconnection and retry
      if (!printResult.success &&
          ZebraErrorBridge.isConnectionRelatedError(printResult)) {
        _logger.info(
            'Manager: Print failed due to connection error, attempting reconnection and retry');
        _statusStreamController
            ?.add('Connection lost, attempting to reconnect...');

        // Try to reconnect once
        final reconnectResult = await connect(
          connectedPrinter!,
          options: CommunicationPolicyOptions(
            skipConnectionRetry: true,
            cancellationToken: options.cancellationToken,
          ),
        );

        if (reconnectResult.success) {
          _logger.info(
              'Manager: Reconnection successful, retrying print operation');
          _statusStreamController?.add('Reconnected, retrying print...');

          // Retry the print operation once
          printResult = await _communicationPolicy!.execute(
            () => _printer.print(data: preparedData, format: detectedFormat),
            'Retry Print Data After Reconnect',
            options: CommunicationPolicyOptions(
              maxAttempts: 1, // Single retry after reconnect
              skipConnectionCheck: true, // We just reconnected
              skipConnectionRetry: true, // Don't retry connection again
              cancellationToken: options.cancellationToken,
              onEvent: (event) {
                _statusStreamController?.add(event.message);
              },
            ),
          );
        } else {
          _logger.error('Manager: Failed to reconnect for print retry');
          _statusStreamController?.add('Failed to reconnect');
        }
      }
      
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
              CommandFactory.createSendCpclFlushBufferCommand(_printer);
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
      final statusCommand =
          CommandFactory.createGetPrinterStatusCommand(_printer);
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


      final statusCommand =
          CommandFactory.createGetDetailedPrinterStatusCommand(_printer);
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
  Future<bool> isPrinterConnected() async {
    await _ensureInitialized();
    final result = await _printer.isPrinterConnected();
    return result.success ? (result.data ?? false) : false;
  }

  /// Primitive: Rotate print orientation
  void rotate() {
    _printer.rotate();
  }

  // ===== INTERNAL HELPER METHODS =====

  /// Ensure the manager is initialized
  Future<void> _ensureInitialized() async {
    if (_controller == null) {
      await initialize();
    }
  }



  /// Dispose of resources
  void dispose() {
    _printer.dispose();
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
