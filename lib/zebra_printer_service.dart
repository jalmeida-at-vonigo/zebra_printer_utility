import 'dart:async';
import 'package:flutter/services.dart';
import 'package:zebrautil/zebrautil.dart';
import 'internal/commands/command_factory.dart';

/// Service for managing Zebra printer operations
///
/// This service provides a high-level interface for printer operations
/// with automatic connection management, error handling, and retry logic.
class ZebraPrinterService {
  ZebraPrinter? _printer;
  ZebraController? _controller;
  ZebraPrinterDiscovery? _discovery;

  StreamController<ZebraDevice?>? _connectionStreamController;
  StreamController<String>? _statusStreamController;
  final Logger _logger = Logger.withPrefix('ZebraPrinterService');

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

  /// Initialize the printer service
  Future<void> initialize() async {
    if (_printer != null) return;

    _logger.info('Initializing ZebraPrinterService');
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
        _logger.warning('Bluetooth permission denied');
        _statusStreamController?.add('Permission denied');
      },
    );
    _logger.info('ZebraPrinterService initialization completed');
  }

  void _onControllerChanged() {
    _connectionStreamController?.add(connectedPrinter);
  }

  /// Connect to a printer by address
  /// Returns Result indicating success or failure with error details
  Future<Result<void>> connect(String address) async {
    _logger.info('Service: Initiating connection to printer: $address');
    await _ensureInitialized();

    try {
      _statusStreamController?.add('Connecting to $address...');

      // Call printer directly - callback-based completion ensures sequencing
      final result = await _printer!.connectToPrinter(address);

      if (result.success) {
        _logger.info('Service: Successfully connected to printer: $address');
        _statusStreamController?.add('Connected to $address');
        return result;
      } else {
        _logger.error(
            'Service: Failed to connect to printer: $address - ${result.error?.message}');
        _statusStreamController?.add('Failed to connect to $address');
        return result;
      }
    } catch (e, stack) {
      _logger.error('Service: Connection error to printer: $address', e, stack);
      _statusStreamController?.add('Connection error: $e');
      if (e.toString().contains('timeout')) {
        return Result.error(
          'Connection timed out',
          code: ErrorCodes.connectionTimeout,
          dartStackTrace: stack,
        );
      }
      return Result.error(
        'Connection error: $e',
        code: ErrorCodes.connectionError,
        dartStackTrace: stack,
      );
    }
  }

  /// Disconnect from current printer
  Future<Result<void>> disconnect() async {
    _logger.info('Service: Initiating printer disconnection');
    await _ensureInitialized();

    if (connectedPrinter != null) {
      try {
        _statusStreamController?.add('Disconnecting...');
        // Call printer directly - callback-based completion ensures sequencing
        final result = await _printer!.disconnect();
        _logger.info('Service: Printer disconnected successfully');
        _statusStreamController?.add('Disconnected');
        return result;
      } catch (e, stack) {
        _logger.error('Service: Disconnect error', e, stack);
        _statusStreamController?.add('Disconnect error: $e');
        return Result.error(
          'Failed to disconnect: $e',
          code: ErrorCodes.connectionError,
          dartStackTrace: stack,
        );
      }
    }
    _logger.info('Service: No printer connected to disconnect');
    return Result.success(); // Already disconnected
  }

  /// Print data to the connected printer
  /// Returns Result indicating success or failure with error details
  ///
  /// [printCompletionDelay] optionally adds a delay after print callback
  /// to ensure the printer has time to process all data. This is useful
  /// for preventing truncated prints when the connection might be closed
  /// shortly after printing.
  Future<Result<void>> print(
    String data, {
    PrintFormat? format,
    bool clearBufferFirst = false,
    ReadinessOptions? readinessOptions,
  }) async {
    _logger.info(
        'Service: Starting print operation, data length: ${data.length} characters');
    await _ensureInitialized();

    if (connectedPrinter == null) {
      _logger.error('Service: Print operation failed - No printer connected');
      _statusStreamController?.add('No printer connected');
      return Result.error(
        'No printer connected',
        code: ErrorCodes.notConnected,
      );
    }

    // Detect format if not specified
    format ??= ZebraSGDCommands.detectDataLanguage(data);
    final isCPCL = format == PrintFormat.cpcl;

    try {
      // Use new readiness manager if options are provided or clearBufferFirst is true
      if (readinessOptions != null || clearBufferFirst) {
        _logger.info(
            'Service: Using new readiness manager for pre-print corrections');

        // Use provided options or create default ones
        final effectiveOptions = readinessOptions ??
            (clearBufferFirst
                ? ReadinessOptions.forPrinting()
                : ReadinessOptions.quick());
        
        // Perform pre-print corrections using new manager
        final correctionResult = await _printer!.prepareForPrint(
          format: format!,
          options: effectiveOptions,
        );

        if (!correctionResult.success) {
          _logger.error(
              'Service: Pre-print correction failed: ${correctionResult.error?.message}');
          return Result.error(
            correctionResult.error?.message ?? 'Pre-print correction failed',
            code: correctionResult.error?.code,
          );
        }
        _logger.info('Service: Pre-print corrections completed successfully');
      }

      // Prepare data based on format
      String preparedData = data;

      if (isCPCL) {
        _logger.info('Service: Detected CPCL format, preparing data');
        // For CPCL, ensure proper line endings
        // Convert any \n to \r\n for CPCL
        preparedData = preparedData.replaceAll(RegExp(r'(?<!\r)\n'), '\r\n');

        // Check if CPCL data ends with FORM but missing PRINT
        if (preparedData.trim().endsWith('FORM') &&
            !preparedData.contains('PRINT')) {
          _logger
              .warning('Service: CPCL data missing PRINT command, adding it');
          _statusStreamController
              ?.add('Warning: CPCL data missing PRINT command, adding it');
          preparedData = '${preparedData.trim()}\r\nPRINT\r\n';
        }

        // Ensure CPCL ends with proper line endings for buffer flush
        if (!preparedData.endsWith('\r\n')) {
          preparedData += '\r\n';
        }

        // Add extra line feeds to ensure complete transmission
        // This helps flush the buffer without using control characters
        preparedData += '\r\n\r\n';
      } else {
        _logger.info('Service: Using ZPL or other format, sending data as-is');
      }

      _logger.info('Service: Sending data to printer');
      _statusStreamController?.add('Sending data to printer...');

      // Send the main data
      final printResult = await _printer!.print(data: preparedData);

      if (printResult.success) {
        _logger.info('Service: Print data sent successfully');
        _statusStreamController?.add('Print data sent successfully');

        // For CPCL, send ETX as a command (not print data) to ensure proper termination
        if (isCPCL) {
          _logger.info('Service: Sending CPCL termination command');
          _statusStreamController?.add('Sending CPCL termination command...');
          await CommandFactory.createSendCpclFlushBufferCommand(_printer!)
              .execute();
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // Best practice: Don't query status during printing
        // Instead, use appropriate delays based on data size and format

        // Calculate delay based on data size
        final dataLength = preparedData.length;
        final baseDelay = format == PrintFormat.cpcl ? 2500 : 2000;
        final sizeMultiplier = (dataLength / 1000).ceil(); // Extra 1s per KB

        Duration effectiveDelay =
            Duration(milliseconds: baseDelay + (sizeMultiplier * 1000));

        _logger.info(
            'Service: Waiting ${effectiveDelay.inMilliseconds}ms for print completion (data size: $dataLength bytes)');
        _statusStreamController?.add(
            'Waiting ${effectiveDelay.inMilliseconds}ms for print to complete (data size: $dataLength bytes)...');
        await Future.delayed(effectiveDelay);

        _logger.info('Service: Print operation completed successfully');
        _statusStreamController?.add('Print operation completed');

        return printResult;
      } else {
        _logger.error(
            'Service: Print operation failed: ${printResult.error?.message}');
        return Result.error(
          'Print failed',
          code: ErrorCodes.printError,
        );
      }
    } catch (e, stack) {
      _logger.error('Service: Print operation error', e, stack);
      _statusStreamController?.add('Print error: $e');
      if (e.toString().contains('timeout')) {
        return Result.error(
          'Print operation timed out',
          code: ErrorCodes.operationTimeout,
          dartStackTrace: stack,
        );
      }
      return Result.error(
        'Print error: $e',
        code: ErrorCodes.printError,
        dartStackTrace: stack,
      );
    }
  }

  /// Auto-print workflow: connect, print, disconnect
  /// If printer is provided, uses that printer
  /// If address is provided, connects to that printer
  /// If neither is provided, discovers and uses the first available printer
  Future<Result<void>> autoPrint(String data,
      {ZebraDevice? printer,
      String? address,
      PrintFormat? format,
      int maxRetries = 3,
      bool verifyConnection = true,
      bool disconnectAfter = true,
      ReadinessOptions? readinessOptions,
      Duration? printCompletionDelay}) async {
    _logger.info(
        'Service: Starting auto-print workflow, data length: ${data.length} characters');
    await _ensureInitialized();

    if (data.isEmpty) {
      _logger.error('Service: Auto-print failed - No data provided');
      return Result.error('No data to print', code: ErrorCodes.invalidData);
    }

    bool connectionInitiatedByAutoPrint = false;

    // Determine target address
    _logger.info('Service: Determining target printer address');
    final addressResult = await _determineTargetAddress(printer, address);
    if (!addressResult.success) {
      _logger.error(
          'Service: Failed to determine target address: ${addressResult.error?.message}');
      return addressResult;
    }
    address = addressResult.data;
    _logger.info('Service: Target address determined: $address');

    // Check connection status directly to see if we need to connect
    _logger.info('Service: Checking current connection status');
    final isConnected = await _printer!.isPrinterConnected();
    
    // Connect if not connected to the target printer
    _logger.info('Service: Ensuring connection to target printer');
    final connectResult =
        await _ensureConnected(address!, isConnected);
    if (!connectResult.success) {
      _logger.error(
          'Service: Failed to connect to target printer: ${connectResult.error?.message}');
      return connectResult;
    }
    connectionInitiatedByAutoPrint = connectResult.data!;
    _logger.info('Service: Successfully connected to target printer');

    // Print with retries - print() method handles readiness checks and corrections
    _logger.info('Service: Starting print operation with retry logic');
    final printResult =
        await _printWithRetry(data,
        format: format,
        maxRetries: maxRetries,
        readinessOptions: readinessOptions);
    if (!printResult.success) {
      _logger.error(
          'Service: Print operation failed after retries: ${printResult.error?.message}');
      if (connectionInitiatedByAutoPrint && disconnectAfter) {
        _logger.info('Service: Disconnecting after failed print operation');
        await disconnect();
      }
      return printResult;
    }

    _logger.info('Service: Print operation completed successfully');

    // Disconnect if we initiated the connection
    if (connectionInitiatedByAutoPrint && disconnectAfter) {
      final delay = printCompletionDelay ?? const Duration(milliseconds: 3000);
      _logger
          .info('Service: Waiting ${delay.inMilliseconds}ms before disconnect');
      _statusStreamController
          ?.add('Waiting ${delay.inMilliseconds}ms before disconnect...');
      await Future.delayed(delay);
      await disconnect();
    }

    _logger.info('Service: Auto-print workflow completed successfully');
    return Result.success();
  }

  /// Determine the target printer address
  Future<Result<String>> _determineTargetAddress(
      ZebraDevice? printer, String? address) async {
    if (printer != null) {
      return Result.success(printer.address);
    }

    if (address != null) {
      return Result.success(address);
    }

    // Find paired Bluetooth printers
    final pairedPrinters = await _findPairedPrinters();
    if (pairedPrinters.isEmpty) {
      return Result.error(
        'No paired Bluetooth printers found',
        code: ErrorCodes.noPrintersFound,
      );
    }

    if (pairedPrinters.length > 1) {
      return Result.error(
        'Multiple paired printers found (${pairedPrinters.length}). Please specify which one to use.',
        code: ErrorCodes.multiplePrintersFound,
      );
    }

    return Result.success(pairedPrinters.first.address);
  }

  /// Ensure connected to the target printer
  Future<Result<bool>> _ensureConnected(
      String address, bool isConnected) async {
    // Check if already connected to the target printer
    if (isConnected == true &&
        connectedPrinter?.address == address) {
      _statusStreamController
          ?.add('Using existing connection to ${connectedPrinter!.name}');
      return Result.success(false); // Connection not initiated by autoPrint
    }

    // Connect to the printer
    _statusStreamController?.add('Connecting to printer...');
    final connectResult = await connect(address);
    if (!connectResult.success) {
      return Result.error(
        'Failed to connect: ${connectResult.error?.message}',
        code: connectResult.error?.code ?? ErrorCodes.connectionError,
      );
    }

    return Result.success(true); // Connection initiated by autoPrint
  }



  /// Print with retry logic - returns Result instead of bool
  Future<Result<void>> _printWithRetry(String data,
      {PrintFormat? format,
      int maxRetries = 3,
      ReadinessOptions? readinessOptions}) async {
    for (int i = 0; i <= maxRetries; i++) {
      try {
        // Check connection before each attempt
        final isConnected = await _verifyConnection();
        if (!isConnected) {
          _statusStreamController
              ?.add('Connection lost, attempting to reconnect...');

          // Try to reconnect if we have a connected printer address
          if (connectedPrinter != null) {
            final reconnectResult = await connect(connectedPrinter!.address);
            if (!reconnectResult.success) {
              _statusStreamController?.add(
                  'Failed to reconnect: ${reconnectResult.error?.message}');
              if (i == maxRetries) {
                return Result.error(
                  'Failed to reconnect after $maxRetries attempts',
                  code: ErrorCodes.connectionError,
                );
              }
              await Future.delayed(const Duration(seconds: 2));
              continue;
            }
            _statusStreamController?.add('Reconnected successfully');
          } else {
            _statusStreamController?.add('No printer to reconnect to');
            return Result.error(
              'No printer to reconnect to',
              code: ErrorCodes.notConnected,
            );
          }
        }

        final result = await print(data,
            format: format, readinessOptions: readinessOptions);

        if (result.success) {
          return Result.success();
        }

        if (i < maxRetries) {
          _statusStreamController
              ?.add('Print failed, retrying... (${i + 1}/$maxRetries)');
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        _statusStreamController?.add('Print error: $e');

        if (i < maxRetries) {
          _statusStreamController?.add('Retrying... (${i + 1}/$maxRetries)');
          await Future.delayed(const Duration(seconds: 2));
        } else {
          _statusStreamController
              ?.add('Print failed after $maxRetries attempts');
          return Result.error(
            'Print failed after $maxRetries attempts: $e',
            code: ErrorCodes.printError,
          );
        }
      }
    }

    _statusStreamController?.add('Print failed after $maxRetries attempts');
    return Result.error(
      'Print failed after $maxRetries attempts',
      code: ErrorCodes.printError,
    );
  }

  /// Find paired Bluetooth printers
  Future<List<ZebraDevice>> _findPairedPrinters() async {
    List<ZebraDevice> pairedPrinters = [];

    try {
      // Check already discovered printers
      if (_controller!.printers.isNotEmpty) {
        pairedPrinters = _controller!.printers.where((p) => !p.isWifi).toList();
      }

      // Quick discovery if needed
      if (pairedPrinters.isEmpty) {
        _statusStreamController
            ?.add('Checking for paired Bluetooth printers...');
        _printer!.startScanning();
        await Future.delayed(const Duration(seconds: 2));
        _printer!.stopScanning();
        pairedPrinters = _controller!.printers.where((p) => !p.isWifi).toList();
      }
    } catch (e) {
      _statusStreamController?.add('Error finding paired printers: $e');
    }

    return pairedPrinters;
  }




  /// Verify printer connection is still active
  Future<bool> _verifyConnection() async {
    try {
      // First check if we think we're connected
      if (connectedPrinter == null) {
        _statusStreamController?.add('No printer in connectedPrinter');
        return false;
      }

      // Then verify with the printer
      final isConnected = await _printer!.isPrinterConnected();

      if (!isConnected) {
        _statusStreamController?.add(
            'Connection verification failed - printer reports disconnected');
        // Update our internal state
        _controller?.updatePrinterStatus("Disconnected", "R");
      } else {
        _statusStreamController?.add('Connection verification successful');
      }

      return isConnected;
    } catch (e) {
      _statusStreamController?.add('Error verifying connection: $e');
      return false;
    }
  }

  // New Readiness API - replaces all old readiness methods

  /// Prepare printer for printing with specified options
  Future<Result<ReadinessResult>> prepareForPrint({
    required PrintFormat format,
    ReadinessOptions? options,
  }) async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      _statusStreamController?.add('No printer connected');
      return Result.error('No printer instance available');
    }

    return await _printer!.prepareForPrint(format: format, options: options);
  }

  /// Get detailed status of the printer
  Future<Result<PrinterReadiness>> getDetailedStatus() async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      _statusStreamController?.add('No printer connected');
      return Result.error('No printer instance available');
    }

    return await _printer!.getDetailedStatus();
  }

  /// Validate if the printer state is ready
  Future<Result<bool>> validatePrinterState() async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      _statusStreamController?.add('No printer connected');
      return Result.error('No printer instance available');
    }

    return await _printer!.validatePrinterState();
  }

  /// Get list of paired/discovered printers for selection
  Future<List<ZebraDevice>> getAvailablePrinters() async {
    await _ensureInitialized();

    // If we already have printers, return them
    if (_controller!.printers.isNotEmpty) {
      return _controller!.printers;
    }

    // Otherwise discover
    final result =
        await discovery.discoverPrinters(timeout: const Duration(seconds: 5));
    return result.success ? result.data ?? [] : [];
  }

  /// Calibrate the connected printer
  Future<Result<void>> calibrate() async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      _statusStreamController?.add('No printer connected');
      return Result.error(
        'No printer connected',
        code: ErrorCodes.notConnected,
      );
    }

    try {
      _statusStreamController?.add('Calibrating printer...');
      _printer!.calibratePrinter();

      // Calibration is fire-and-forget, no callback available
      _statusStreamController?.add('Calibration command sent');
      return Result.success();
    } catch (e, stack) {
      _statusStreamController?.add('Calibration error: $e');
      return Result.error(
        'Calibration failed: $e',
        code: ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }

  /// Set printer darkness/density
  Future<Result<void>> setDarkness(int darkness) async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      _statusStreamController?.add('No printer connected');
      return Result.error(
        'No printer connected',
        code: ErrorCodes.notConnected,
      );
    }

    if (darkness < -30 || darkness > 30) {
      _statusStreamController?.add('Darkness must be between -30 and 30');
      return Result.error(
        'Darkness must be between -30 and 30',
        code: ErrorCodes.invalidArgument,
      );
    }

    try {
      _printer!.setDarkness(darkness);
      _statusStreamController?.add('Darkness set to $darkness');
      return Result.success();
    } catch (e, stack) {
      _statusStreamController?.add('Set darkness error: $e');
      return Result.error(
        'Failed to set darkness: $e',
        code: ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }

  /// Set media type
  Future<Result<void>> setMediaType(EnumMediaType type) async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      _statusStreamController?.add('No printer connected');
      return Result.error(
        'No printer connected',
        code: ErrorCodes.notConnected,
      );
    }

    try {
      _printer!.setMediaType(type);
      _statusStreamController?.add('Media type set to ${type.name}');
      return Result.success();
    } catch (e, stack) {
      _statusStreamController?.add('Set media type error: $e');
      return Result.error(
        'Failed to set media type: $e',
        code: ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }

  /// Check if a printer is currently connected
  Future<bool> isConnected() async {
    await _ensureInitialized();
    return await _printer!.isPrinterConnected();
  }

  /// Force reconnect to the current printer
  Future<Result<void>> forceReconnect() async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      return Result.error(
        'No printer to reconnect to',
        code: ErrorCodes.notConnected,
      );
    }

    try {
      _statusStreamController
          ?.add('Force reconnecting to ${connectedPrinter!.name}...');

      // Disconnect first
      await disconnect();

      // Then reconnect
      final result = await connect(connectedPrinter!.address);

      if (result.success) {
        _statusStreamController?.add('Force reconnect successful');
      } else {
        _statusStreamController
            ?.add('Force reconnect failed: ${result.error?.message}');
      }

      return result;
    } catch (e, stack) {
      _statusStreamController?.add('Force reconnect error: $e');
      return Result.error(
        'Force reconnect error: $e',
        code: ErrorCodes.connectionError,
        dartStackTrace: stack,
      );
    }
  }

  /// Rotate print orientation
  void rotate() {
    _printer?.rotate();
  }

  /// Ensure the service is initialized
  Future<void> _ensureInitialized() async {
    if (_printer == null) {
      await initialize();
    }
  }

  /// Dispose of resources
  void dispose() {
    _printer?.dispose();
    _discovery?.dispose();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _connectionStreamController?.close();
    _statusStreamController?.close();
  }

  /// Test method - Direct print without operation queue
  Future<Result<void>> directPrint(String data) async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      return Result.error(
        'No printer connected',
        code: ErrorCodes.notConnected,
      );
    }

    try {
      _statusStreamController?.add('Direct printing...');
      final result = await _printer!.print(data: data);

      if (result.success) {
        _statusStreamController?.add('Direct print successful');
        return Result.success();
      } else {
        _statusStreamController
            ?.add('Direct print failed: ${result.error?.message}');
        return result;
      }
    } catch (e, stack) {
      _statusStreamController?.add('Direct print error: $e');
      return Result.error(
        'Direct print error: $e',
        code: ErrorCodes.printError,
        dartStackTrace: stack,
      );
    }
  }

  /// Direct CPCL print method that uses only the minimal working approach
  /// This method replicates exactly what worked in version 2.0.23
  Future<Result<void>> printCPCLDirect(String data) async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      return Result.error(
        'No printer connected',
        code: ErrorCodes.notConnected,
      );
    }

    try {
      // 1. Prepare CPCL data with line ending conversions
      String preparedData = data.replaceAll(RegExp(r'(?<!\r)\n'), '\r\n');

      // 2. Check if CPCL data ends with FORM but missing PRINT
      if (preparedData.trim().endsWith('FORM') &&
          !preparedData.contains('PRINT')) {
        preparedData = '${preparedData.trim()}\r\nPRINT\r\n';
      }

      // 3. Ensure CPCL ends with proper line endings
      if (!preparedData.endsWith('\r\n')) {
        preparedData += '\r\n';
      }

      // 4. Add extra line feeds to ensure complete transmission
      preparedData += '\r\n\r\n';

      // 5. Send the data
      final printResult = await _printer!.print(data: preparedData);

      if (printResult.success) {
        // 6. Send ETX as a command to ensure proper termination
        await CommandFactory.createSendCpclFlushBufferCommand(_printer!)
            .execute();
        await Future.delayed(const Duration(milliseconds: 100));

        // 7. Use fixed delay of 2500ms for CPCL
        await Future.delayed(const Duration(milliseconds: 2500));

        return Result.success();
      } else {
        return Result.error(
          printResult.error?.message ?? 'Print failed',
          code: printResult.error?.code ?? ErrorCodes.printError,
        );
      }
    } catch (e) {
      return Result.error(
        'Print error: $e',
        code: ErrorCodes.printError,
      );
    }
  }

  // ===== Internal helper methods =====

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

  /// Run comprehensive diagnostics on the printer
  Future<Result<Map<String, dynamic>>> runDiagnostics() async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      final diagnostics = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'connected': false,
        'printerInfo': {},
        'status': {},
        'settings': {},
        'errors': ['No printer connected'],
        'recommendations': ['Connect to a printer first'],
      };
      return Result.success(diagnostics);
    }

    final result = await _printer!.runDiagnostics();

    // Add printer info to the diagnostics result
    if (result.success && result.data != null) {
      result.data!['printerInfo'] = {
        'name': connectedPrinter!.name,
        'address': connectedPrinter!.address,
        'isWifi': connectedPrinter!.isWifi,
      };
    }

    return result;
  }

  /// Send an SGD command directly to the printer
  Future<Result<String?>> sendSGDCommand(String command) async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      return Result.error(
        'No printer connected',
        code: ErrorCodes.notConnected,
      );
    }

    try {
      _statusStreamController?.add('Sending SGD command: $command');

      // Use the sendCommand method from ZebraPrinter
      _printer!.sendCommand(command);

      // For SGD commands that return values, we need to read the response
      // This is a simplified implementation - enhance as needed
      return Result.success(null);
    } catch (e, stack) {
      _statusStreamController?.add('SGD command error: $e');
      return Result.error(
        'Failed to send SGD command: $e',
        code: ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }

  /// Clear printer buffer and reset print engine state
  /// This helps prevent issues where the printer is waiting for more data
  Future<Result<void>> clearPrinterBuffer(PrintFormat format) async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      return Result.error(
        'No printer connected',
        code: ErrorCodes.notConnected,
      );
    }

    // Use the new readiness manager to clear buffer
    const options = ReadinessOptions(
      checkConnection: false,
      checkMedia: false,
      checkHead: false,
      checkPause: false,
      checkErrors: false,
      clearBuffer: true,
    );
    
    final result =
        await _printer!.prepareForPrint(format: format, options: options);
    if (result.success) {
      return Result.success();
    } else {
      return Result.error(
        'Failed to clear buffer: ${result.error?.message}',
        code: result.error?.code,
      );
    }
  }

  /// Flush the printer's buffer to ensure all data is processed
  /// This is especially important for CPCL printing
  Future<Result<void>> flushPrintBuffer(PrintFormat format) async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      return Result.error(
        'No printer connected',
        code: ErrorCodes.notConnected,
      );
    }

    // Use the new readiness manager to flush buffer
    const options = ReadinessOptions(
      checkConnection: false,
      checkMedia: false,
      checkHead: false,
      checkPause: false,
      checkErrors: false,
      flushBuffer: true,
    );
    
    final result =
        await _printer!.prepareForPrint(format: format, options: options);
    if (result.success) {
      return Result.success();
    } else {
      return Result.error(
        'Failed to flush buffer: ${result.error?.message}',
        code: result.error?.code,
      );
    }
  }
  


}
