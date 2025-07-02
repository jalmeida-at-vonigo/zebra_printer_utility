import 'dart:async';
import 'package:zebrautil/zebrautil.dart';
import 'package:flutter/services.dart';
/// A simplified service for Zebra printer operations.
/// Provides a clean async/await API with proper error handling.
class ZebraPrinterService {
  ZebraPrinter? _printer;
  ZebraController? _controller;
  ZebraOperationQueue? _operationQueue;

  StreamController<List<ZebraDevice>>? _devicesStreamController;
  StreamController<ZebraDevice?>? _connectionStreamController;
  StreamController<String>? _statusStreamController;

  Timer? _discoveryTimer;
  bool _isScanning = false;

  /// Whether discovery is currently active
  bool get isScanning => _isScanning;

  /// Stream of discovered devices
  Stream<List<ZebraDevice>> get devices =>
      _devicesStreamController?.stream ?? const Stream.empty();

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

  /// List of discovered printers
  List<ZebraDevice> get discoveredPrinters => _controller?.printers ?? [];

  /// Initialize the printer service
  Future<void> initialize() async {
    if (_printer != null) return;

    _controller = ZebraController();
    _devicesStreamController = StreamController<List<ZebraDevice>>.broadcast();
    _connectionStreamController = StreamController<ZebraDevice?>.broadcast();
    _statusStreamController = StreamController<String>.broadcast();

    // Listen to controller changes
    _controller!.addListener(_onControllerChanged);

    _printer = await _getPrinterInstance(
      controller: _controller,
      onDiscoveryError: (code, message) {
        _statusStreamController?.add('Discovery error: $message');
      },
      onPermissionDenied: () {
        _statusStreamController?.add('Permission denied');
      },
    );
    
    // Initialize operation queue
    _operationQueue = ZebraOperationQueue(
      onExecuteOperation: _executeOperation,
      onError: (error) =>
          _statusStreamController?.add('Operation error: $error'),
    );
  }

  void _onControllerChanged() {
    _devicesStreamController?.add(_controller!.printers);
    _connectionStreamController?.add(connectedPrinter);
  }
  
  /// Execute an operation from the queue
  Future<dynamic> _executeOperation(ZebraOperation operation) async {
    switch (operation.type) {
      case OperationType.connect:
        final address = operation.parameters['address'] as String;
        return await _doConnect(address);

      case OperationType.disconnect:
        return await _doDisconnect();

      case OperationType.print:
        final data = operation.parameters['data'] as String;
        final ensureMode = operation.parameters['ensureMode'] as bool? ?? true;
        return await _doPrint(data, ensureMode: ensureMode);

      case OperationType.setSetting:
        final setting = operation.parameters['setting'] as String;
        final value = operation.parameters['value'] as String;
        return await _doSetSetting(setting, value);

      case OperationType.getSetting:
        final setting = operation.parameters['setting'] as String;
        return await _doGetSetting(setting);

      case OperationType.setPrinterMode:
        final mode = operation.parameters['mode'] as String;
        return await _doSetPrinterMode(mode);

      case OperationType.checkStatus:
        return await _doCheckStatus();

      default:
        throw Exception('Unknown operation type: ${operation.type}');
    }
  }

  /// Discover available printers (both Bluetooth and Network)
  /// Returns Result with list of discovered devices
  Future<Result<List<ZebraDevice>>> discoverPrinters({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await _ensureInitialized();

    try {
      final completer = Completer<List<ZebraDevice>>();

      // Start discovery
      _isScanning = true;
      _printer!.startScanning();
      _statusStreamController?.add('Scanning for printers...');

      // Set up timeout
      _discoveryTimer?.cancel();
      _discoveryTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          _printer!.stopScanning();
          _isScanning = false;
          _statusStreamController?.add('Discovery completed');
          completer.complete(_controller!.printers);
        }
      });

      final devices = await completer.future;
      return Result.success(devices);
    } catch (e, stack) {
      _statusStreamController?.add('Discovery error: $e');
      return Result.error(
        'Failed to discover printers: $e',
        code: ErrorCodes.discoveryError,
        dartStackTrace: stack,
      );
    }
  }

  /// Stop printer discovery
  Future<void> stopDiscovery() async {
    await _ensureInitialized();
    _discoveryTimer?.cancel();
    _printer!.stopScanning();
    _isScanning = false;
    _statusStreamController?.add('Discovery stopped');
  }

  /// Connect to a printer by address
  /// Returns Result indicating success or failure with error details
  Future<Result<void>> connect(String address) async {
    await _ensureInitialized();

    try {
      _statusStreamController?.add('Connecting to $address...');

      final result = await _operationQueue!.enqueue<Result<void>>(
        OperationType.connect,
        {'address': address},
        timeout: const Duration(seconds: 10),
      );

      if (result.success) {
        _statusStreamController?.add('Connected to $address');
        return result;
      } else {
        _statusStreamController?.add('Failed to connect to $address');
        return result;
      }
    } catch (e, stack) {
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
    await _ensureInitialized();

    if (connectedPrinter != null) {
      try {
        _statusStreamController?.add('Disconnecting...');
        await _operationQueue!.enqueue<void>(
          OperationType.disconnect,
          {},
          timeout: const Duration(seconds: 5),
        );
        _statusStreamController?.add('Disconnected');
        return Result.success();
      } catch (e, stack) {
        _statusStreamController?.add('Disconnect error: $e');
        return Result.error(
          'Failed to disconnect: $e',
          code: ErrorCodes.connectionError,
          dartStackTrace: stack,
        );
      }
    }
    return Result.success(); // Already disconnected
  }

  /// Print data to the connected printer
  /// Returns Result indicating success or failure with error details
  Future<Result<void>> print(String data, {PrintFormat? format}) async {
    await _ensureInitialized();
    
    if (connectedPrinter == null) {
      _statusStreamController?.add('No printer connected');
      return Result.error(
        'No printer connected',
        code: ErrorCodes.notConnected,
      );
    }
    
    try {
      _statusStreamController?.add('Printing...');
      
      final success = await _operationQueue!.enqueue<bool>(
        OperationType.print,
        {
          'data': data,
          'ensureMode': true, // Enable automatic mode switching
        },
        timeout: const Duration(seconds: 30),
      );
      
      if (success) {
        _statusStreamController?.add('Print sent successfully');
        return Result.success();
      } else {
        return Result.error(
          'Print failed',
          code: ErrorCodes.printError,
        );
      }
    } catch (e, stack) {
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

  
  /// Auto-print workflow: discover, connect, print, disconnect
  /// If printer is provided, uses that printer
  /// If address is provided, connects to that printer
  /// If neither is provided, discovers and uses the first available printer
  Future<Result<void>> autoPrint(String data,
      {ZebraDevice? printer,
      String? address,
      PrintFormat? format,
      int maxRetries = 3,
      bool verifyConnection = true,
      bool disconnectAfter = true}) async {
    await _ensureInitialized();

    // Validate input data
    if (data.isEmpty) {
      _statusStreamController?.add('Error: No data to print');
      return Result.error(
        'No data to print',
        code: ErrorCodes.invalidData,
      );
    }

    bool shouldDisconnect = false;

    try {
      // If printer is provided, use it directly
      if (printer != null) {
        address = printer.address;

        // Check if already connected to this printer
        if (connectedPrinter != null &&
            connectedPrinter!.address == printer.address) {
          _statusStreamController
              ?.add('Using existing connection to ${printer.name}');
          
          // Verify connection is still active
          if (verifyConnection) {
            final isStillConnected = await _verifyConnection();
            if (!isStillConnected) {
              _statusStreamController?.add('Connection lost, reconnecting...');
              await disconnect();
            } else {
              // Just print and return (don't disconnect if already connected)
              final printResult = await _printWithRetry(data,
                  format: format, maxRetries: maxRetries);
              return printResult
                  ? Result.success()
                  : Result.error(
                      'Print failed',
                      code: ErrorCodes.printError,
                    );
            }
          } else {
            // Just print without verification
            final printResult = await _printWithRetry(data,
                format: format, maxRetries: maxRetries);
            return printResult
                ? Result.success()
                : Result.error(
                    'Print failed',
                    code: ErrorCodes.printError,
                  );
          }
        }
      }

      // If already connected to the right printer, verify and use it
      if (connectedPrinter != null &&
          (address == null || connectedPrinter!.address == address)) {
        
        if (verifyConnection) {
          final isStillConnected = await _verifyConnection();
          if (isStillConnected) {
            _statusStreamController?.add('Using existing connection');
            final printResult = await _printWithRetry(data,
                format: format, maxRetries: maxRetries);
            return printResult
                ? Result.success()
                : Result.error(
                    'Print failed',
                    code: ErrorCodes.printError,
                  );
          } else {
            _statusStreamController?.add('Connection lost, reconnecting...');
            await disconnect();
          }
        } else {
          final printResult = await _printWithRetry(data,
              format: format, maxRetries: maxRetries);
          return printResult
              ? Result.success()
              : Result.error(
                  'Print failed',
                  code: ErrorCodes.printError,
                );
        }
      }

      // Disconnect from current printer if needed
      if (connectedPrinter != null) {
        _statusStreamController?.add('Disconnecting from current printer...');
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // If no address provided, look for paired printers only
      if (address == null) {
        _statusStreamController?.add('Looking for paired printers...');
        
        // Get paired Bluetooth printers
        List<ZebraDevice> pairedPrinters = [];

        try {
          // First check if we have any already discovered printers
          if (_controller!.printers.isNotEmpty) {
            // Filter for Bluetooth printers (paired ones)
            pairedPrinters =
                _controller!.printers.where((p) => !p.isWifi).toList();
          }

          // If no paired printers in cache, do a quick discovery
          if (pairedPrinters.isEmpty) {
            _statusStreamController
                ?.add('Checking for paired Bluetooth printers...');

            // Start discovery but only wait briefly for Bluetooth
            _printer!.startScanning();
            await Future.delayed(const Duration(seconds: 2));
            _printer!.stopScanning();

            // Get only Bluetooth (paired) printers
            pairedPrinters =
                _controller!.printers.where((p) => !p.isWifi).toList();
          }
        } catch (e) {
          _statusStreamController?.add('Error finding paired printers: $e');
        }

        if (pairedPrinters.isEmpty) {
          _statusStreamController?.add(
              'No paired Bluetooth printers found. Please pair a printer first.');
          return Result.error(
            'No paired Bluetooth printers found',
            code: ErrorCodes.noPrintersFound,
          );
        }

        // If only one paired printer, use it
        if (pairedPrinters.length == 1) {
          address = pairedPrinters.first.address;
          _statusStreamController
              ?.add('Using paired printer: ${pairedPrinters.first.name}');
        } else {
          // Multiple paired printers - fail and ask user to specify
          _statusStreamController
              ?.add(
              'Multiple paired printers found (${pairedPrinters.length}). Please specify which one to use.');
          return Result.error(
            'Multiple paired printers found (${pairedPrinters.length}). Please specify which one to use.',
            code: ErrorCodes.multiplePrintersFound,
          );
        }
      }

      // Connect to the printer with retries
      _statusStreamController?.add('Connecting to printer...');
      Result<void>? connectResult;

      for (int i = 0; i <= maxRetries; i++) {
        connectResult = await connect(address);

        if (connectResult.success) {
          shouldDisconnect = disconnectAfter;
          break;
        }

        if (i < maxRetries) {
          _statusStreamController
              ?.add('Connection failed, retrying... (${i + 1}/$maxRetries)');
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (connectResult == null || !connectResult.success) {
        _statusStreamController
            ?.add('Failed to connect after $maxRetries attempts');
        return Result.error(
          'Failed to connect after $maxRetries attempts',
          code: ErrorCodes.connectionError,
        );
      }

      // Verify connection and readiness before printing
      if (verifyConnection) {
        final readinessResult = await checkPrinterReadiness();
        if (!readinessResult.success) {
          _statusStreamController?.add('Failed to check printer readiness');
          if (shouldDisconnect) await disconnect();
          return readinessResult.map((_) => null);
        }

        final readiness = readinessResult.data!;
        if (!readiness.isReady) {
          _statusStreamController
              ?.add('Printer not ready: ${readiness.summary}');
          if (shouldDisconnect) await disconnect();
          return Result.error(
            'Printer not ready: ${readiness.summary}',
            code: ErrorCodes.printerNotReady,
          );
        }
      }

      // Print the data with retries
      final printed =
          await _printWithRetry(data, format: format, maxRetries: maxRetries);

      // Disconnect after printing if requested
      if (shouldDisconnect && disconnectAfter) {
        _statusStreamController?.add('Disconnecting...');
        await disconnect();
      }

      return printed
          ? Result.success()
          : Result.error(
              'Print failed after retries',
              code: ErrorCodes.printError,
            );
    } catch (e, stack) {
      _statusStreamController?.add('Auto-print error: $e');
      
      // Clean up on error
      if (shouldDisconnect && connectedPrinter != null) {
        try {
          await disconnect();
        } catch (_) {}
      }

      return Result.error(
        'Auto-print error: $e',
        code: ErrorCodes.unknownError,
        dartStackTrace: stack,
      );
    }
  }

  /// Print with retry logic
  Future<bool> _printWithRetry(String data,
      {PrintFormat? format, int maxRetries = 3}) async {
    for (int i = 0; i <= maxRetries; i++) {
      try {
        final result = await print(data, format: format);

        if (result.success) {
          return true;
        }

        if (i < maxRetries) {
          _statusStreamController
              ?.add('Print failed, retrying... (${i + 1}/$maxRetries)');

          // Check if still connected
          final isConnected = await _verifyConnection();
          if (!isConnected) {
            _statusStreamController?.add('Connection lost during print');
            return false;
          }

          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        if (i < maxRetries) {
          _statusStreamController
              ?.add('Print error: $e, retrying... (${i + 1}/$maxRetries)');
          await Future.delayed(const Duration(seconds: 1));
        } else {
          throw e;
        }
      }
    }

    _statusStreamController?.add('Print failed after $maxRetries attempts');
    return false;
  }

  /// Verify printer connection is still active
  Future<bool> _verifyConnection() async {
    try {
      // First check if we think we're connected
      if (connectedPrinter == null) return false;

      // Then verify with the printer
      final isConnected = await _printer!.isPrinterConnected();

      if (!isConnected) {
        _statusStreamController?.add('Connection verification failed');
      }

      return isConnected;
    } catch (e) {
      _statusStreamController?.add('Error verifying connection: $e');
      return false;
    }
  }

  /// Check if printer is ready to print
  Future<Result<PrinterReadiness>> checkPrinterReadiness() async {
    final readiness = PrinterReadiness();

    try {
      if (connectedPrinter == null) {
        readiness.isReady = false;
        readiness.isConnected = false;
        readiness.errors.add('Not connected to printer');
        return Result.success(readiness);
      }

      // Check connection
      readiness.isConnected = await _verifyConnection();
      if (readiness.isConnected == false) {
        readiness.isReady = false;
        readiness.errors.add('Printer connection lost');
        return Result.error(
          'Printer connection lost',
          code: ErrorCodes.connectionLost,
        );
      }

      // Now we can implement full printer readiness checks
      try {
        readiness.fullCheckPerformed = true;
        
        // Check media status
        readiness.mediaStatus = await _doGetSetting('media.status');
        if (readiness.mediaStatus != null) {
          final mediaLower = readiness.mediaStatus!.toLowerCase();
          readiness.hasMedia =
              mediaLower.contains('ok') || mediaLower.contains('ready');
          if (readiness.hasMedia == false) {
            readiness.warnings.add('Media not ready: ${readiness.mediaStatus}');
          }
        }

        // Check head latch
        readiness.headStatus = await _doGetSetting('head.latch');
        if (readiness.headStatus != null) {
          final headLower = readiness.headStatus!.toLowerCase();
          readiness.headClosed =
              headLower.contains('ok') || headLower.contains('closed');
          if (readiness.headClosed == false) {
            readiness.errors.add('Print head is open');
          }
        }

        // Check pause status
        readiness.pauseStatus = await _doGetSetting('device.pause');
        if (readiness.pauseStatus != null) {
          final pauseLower = readiness.pauseStatus!.toLowerCase();
          readiness.isPaused = pauseLower == 'true' || pauseLower == 'on';
          if (readiness.isPaused == true) {
            readiness.warnings.add('Printer is paused');
          }
        }

        // Check for errors
        readiness.hostStatus = await _doGetSetting('device.host_status');
        if (readiness.hostStatus != null) {
          final hostLower = readiness.hostStatus!.toLowerCase();
          if (!hostLower.contains('ok')) {
            readiness.errors.add('Printer error: ${readiness.hostStatus}');
          }
        }

        // Determine overall readiness - only consider non-null values
        readiness.isReady = (readiness.isConnected ?? false) &&
            (readiness.headClosed ?? true) &&
            !(readiness.isPaused ?? false) &&
            readiness.errors.isEmpty;

        if (readiness.isReady) {
          _statusStreamController?.add('Printer is ready');
        } else {
          _statusStreamController
              ?.add('Printer not ready: ${readiness.summary}');
        }
      } catch (e) {
        // If we can't get status, set what we know
        readiness.fullCheckPerformed = false;
        _statusStreamController
            ?.add('Could not check full status, assuming ready if connected');
        readiness.isReady = readiness.isConnected ?? false;
      }

      return Result.success(readiness);
    } catch (e, stack) {
      readiness.isReady = false;
      readiness.errors.add('Error checking printer status: $e');
      return Result.error(
        'Error checking printer status: $e',
        code: ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }

  /// Get list of paired/discovered printers for selection
  Future<List<ZebraDevice>> getAvailablePrinters() async {
    await _ensureInitialized();

    // If we already have printers, return them
    if (_controller!.printers.isNotEmpty) {
      return _controller!.printers;
    }

    // Otherwise discover
    final result = await discoverPrinters(timeout: const Duration(seconds: 5));
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

      await Future.delayed(const Duration(milliseconds: 500));

      _statusStreamController?.add('Calibration complete');
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
    _discoveryTimer?.cancel();
    _operationQueue?.dispose();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _devicesStreamController?.close();
    _connectionStreamController?.close();
    _statusStreamController?.close();
  }
  
  // ===== Internal operation implementations =====

  Future<Result<void>> _doConnect(String address) async {
    final result = await _printer!.connectToPrinter(address);
    return result;
  }

  Future<Result<void>> _doDisconnect() async {
    return await _printer!.disconnect();
  }

  Future<bool> _doPrint(String data, {bool ensureMode = true}) async {
    if (ensureMode) {
      // Detect data format and ensure printer is in correct mode
      final language = ZebraSGDCommands.detectDataLanguage(data);
      if (language != null) {
        // Check current printer mode
        final currentMode = await _doGetSetting('device.languages');
        if (currentMode != null &&
            !ZebraSGDCommands.isLanguageMatch(currentMode, language)) {
          // Switch printer mode
          await _doSetPrinterMode(language);
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    // Send the print data
    final result = await _printer!.print(data: data);
    return result.success;
  }

  Future<bool> _doSetSetting(String setting, String value) async {
    final command = ZebraSGDCommands.setCommand(setting, value);
    await _printer!.print(data: command);
    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  Future<String?> _doGetSetting(String setting) async {
    try {
      // Use the new getSetting method that reads responses
      final response = await _printer!.channel.invokeMethod<String>(
        'getSetting',
        {'setting': setting},
      );

      if (response != null && response.isNotEmpty) {
        // Parse the response using our SGD parser
        return ZebraSGDCommands.parseResponse(response);
      }
      
      return null;
    } catch (e) {
      _statusStreamController?.add('Failed to get setting $setting: $e');
      return null;
    }
  }

  Future<bool> _doSetPrinterMode(String mode) async {
    final command = mode.toLowerCase() == 'zpl'
        ? ZebraSGDCommands.setZPLMode()
        : ZebraSGDCommands.setCPCLMode();

    await _printer!.print(data: command);
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  Future<Map<String, dynamic>> _doCheckStatus() async {
    // Send status command
    await _printer!.print(data: ZebraSGDCommands.getPrinterStatus);

    // TODO: Implement status response parsing
    // For now, return simulated status
    return {
      'status': 'ready',
      'media_present': true,
      'head_closed': true,
      'paused': false,
      'errors': [],
    };
  }

  /// Create a new printer instance
  static Future<ZebraPrinter> _getPrinterInstance({
    ZebraController? controller,
    Function(String code, String? message)? onDiscoveryError,
    Function()? onPermissionDenied,
  }) async {
    const platform = MethodChannel('zebrautil');

    // Get instance ID from platform
    final int instanceId = await platform.invokeMethod('getInstance');

    // Return new printer instance
    return ZebraPrinter(
      instanceId.toString(),
      controller: controller,
      onDiscoveryError: onDiscoveryError,
      onPermissionDenied: onPermissionDenied,
    );
  }
}

