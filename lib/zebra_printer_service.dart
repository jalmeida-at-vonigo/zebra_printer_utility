import 'dart:async';
import 'package:flutter/services.dart';
import 'package:zebrautil/zebrautil.dart';

/// Service for managing Zebra printer operations
///
/// This service provides a high-level interface for printer operations
/// with automatic connection management, error handling, and retry logic.
class ZebraPrinterService {
  ZebraPrinter? _printer;
  ZebraController? _controller;

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
    
  }

  void _onControllerChanged() {
    _devicesStreamController?.add(_controller!.printers);
    _connectionStreamController?.add(connectedPrinter);
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

      // Call printer directly - callback-based completion ensures sequencing
      final result = await _printer!.connectToPrinter(address);

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
        // Call printer directly - callback-based completion ensures sequencing
        final result = await _printer!.disconnect();
        _statusStreamController?.add('Disconnected');
        return result;
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
      
      // Call printer directly - callback-based completion ensures sequencing
      final result = await _printer!.print(data: data);
      
      if (result.success) {
        _statusStreamController?.add('Print sent successfully');
        return result;
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
      bool disconnectAfter = true,
      AutoCorrectionOptions? autoCorrectionOptions}) async {
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
      // If printer is provided, use its address
      if (printer != null) {
        address = printer.address;
      }

      // Check if we're already connected to the requested printer
      if (address != null &&
          connectedPrinter != null &&
          connectedPrinter!.address == address) {
        _statusStreamController
            ?.add('Using existing connection to ${connectedPrinter!.name}');
        
        // Verify connection is still active if requested
        if (verifyConnection) {
          final isStillConnected = await _verifyConnection();
          if (!isStillConnected) {
            _statusStreamController?.add('Connection lost, reconnecting...');
            await disconnect();
            // Continue to reconnection logic below
          } else {
            // Connection is good, proceed with printing
            // Check printer readiness if requested
            if (verifyConnection) {
              final readinessResult = await checkPrinterReadiness();
              if (!readinessResult.success) {
                _statusStreamController
                    ?.add('Failed to check printer readiness');
                return Result.error(
                  readinessResult.error?.message ??
                      'Failed to check printer readiness',
                  code:
                      readinessResult.error?.code ?? ErrorCodes.operationError,
                );
              }

              var readiness = readinessResult.data!;
              if (!readiness.isReady) {
                _statusStreamController
                    ?.add('Printer not ready: ${readiness.summary}');

                // Attempt auto-correction for certain issues
                final canAutoCorrect = readiness.isPaused == true ||
                    (readiness.errors.isNotEmpty &&
                        readiness.headClosed != false);

                if (canAutoCorrect) {
                  _statusStreamController?.add('Attempting auto-correction...');
                  final options =
                      autoCorrectionOptions ?? AutoCorrectionOptions.safe();
                  final corrector = AutoCorrector(
                    printer: _printer!,
                    options: options,
                    statusCallback: (msg) => _statusStreamController?.add(msg),
                  );
                  final correctionResult =
                      await corrector.correctReadiness(readiness);

                  if (correctionResult.success &&
                      correctionResult.data == true) {
                    // Re-check readiness after corrections
                    final recheckResult = await checkPrinterReadiness();
                    if (recheckResult.success && recheckResult.data!.isReady) {
                      _statusStreamController?.add(
                          'Auto-correction successful, printer is now ready');
                      readiness = recheckResult.data!;
                      // Continue with printing
                    } else {
                      // Still not ready after corrections
                      return Result.error(
                        'Printer still not ready after auto-correction: ${recheckResult.data?.summary ?? readiness.summary}',
                        code: ErrorCodes.printerNotReady,
                      );
                    }
                  } else {
                    // Could not auto-correct
                    return Result.error(
                      'Printer not ready and auto-correction failed: ${readiness.summary}',
                      code: ErrorCodes.printerNotReady,
                    );
                  }
                } else {
                  // Cannot auto-correct these issues
                  return Result.error(
                    'Printer not ready: ${readiness.summary}',
                    code: ErrorCodes.printerNotReady,
                  );
                }
              }
            }

            // Print the data with retries
            final printed = await _printWithRetry(data,
                format: format, maxRetries: maxRetries);
            
            return printed
                ? Result.success()
                : Result.error('Print failed', code: ErrorCodes.printError);
          }
        } else {
          // No verification requested, just print
          final printResult = await _printWithRetry(data,
              format: format, maxRetries: maxRetries);
          return printResult
              ? Result.success()
              : Result.error('Print failed', code: ErrorCodes.printError);
        }
      }

      // If we have a different printer connected, disconnect first
      if (connectedPrinter != null &&
          address != null &&
          connectedPrinter!.address != address) {
        _statusStreamController?.add('Disconnecting from different printer...');
        await disconnect();
      }

      // If no address provided, look for paired printers
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
            await Future.delayed(const Duration(
                seconds: 2)); // NECESSARY: Hardware needs time to discover
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
          _statusStreamController?.add(
              'Multiple paired printers found (${pairedPrinters.length}). Please specify which one to use.');
          return Result.error(
            'Multiple paired printers found (${pairedPrinters.length}). Please specify which one to use.',
            code: ErrorCodes.multiplePrintersFound,
          );
        }
      }

      // At this point we have an address but are not connected - connect now
      if (connectedPrinter == null || connectedPrinter!.address != address) {
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
            await Future.delayed(
                const Duration(seconds: 2)); // NECESSARY: Retry delay
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
      }

      // Verify connection and readiness before printing
      if (verifyConnection) {
        final readinessResult = await checkPrinterReadiness();
        if (!readinessResult.success) {
          _statusStreamController?.add('Failed to check printer readiness');
          if (shouldDisconnect) await disconnect();
          return Result.error(
            readinessResult.error?.message ??
                'Failed to check printer readiness',
            code: readinessResult.error?.code ?? ErrorCodes.operationError,
          );
        }

        var readiness = readinessResult.data!;
        if (!readiness.isReady) {
          _statusStreamController
              ?.add('Printer not ready: ${readiness.summary}');
          
          // Attempt auto-correction for certain issues
          final canAutoCorrect = readiness.isPaused == true ||
              (readiness.errors.isNotEmpty && readiness.headClosed != false);

          if (canAutoCorrect) {
            _statusStreamController?.add('Attempting auto-correction...');
            final options =
                autoCorrectionOptions ?? AutoCorrectionOptions.safe();
            final corrector = AutoCorrector(
              printer: _printer!,
              options: options,
              statusCallback: (msg) => _statusStreamController?.add(msg),
            );
            final correctionResult =
                await corrector.correctReadiness(readiness);

            if (correctionResult.success && correctionResult.data == true) {
              // Re-check readiness after corrections
              final recheckResult = await checkPrinterReadiness();
              if (recheckResult.success && recheckResult.data!.isReady) {
                _statusStreamController
                    ?.add('Auto-correction successful, printer is now ready');
                readiness = recheckResult.data!;
                // Continue with printing
              } else {
                // Still not ready after corrections
                if (shouldDisconnect) await disconnect();
                return Result.error(
                  'Printer still not ready after auto-correction: ${recheckResult.data?.summary ?? readiness.summary}',
                  code: ErrorCodes.printerNotReady,
                );
              }
            } else {
              // Could not auto-correct
              if (shouldDisconnect) await disconnect();
              return Result.error(
                'Printer not ready and auto-correction failed: ${readiness.summary}',
                code: ErrorCodes.printerNotReady,
              );
            }
          } else {
            // Cannot auto-correct these issues
            if (shouldDisconnect) await disconnect();
            return Result.error(
              'Printer not ready: ${readiness.summary}',
              code: ErrorCodes.printerNotReady,
            );
          }
        }
      }

      // Print the data with retries
      final printed =
          await _printWithRetry(data, format: format, maxRetries: maxRetries);

      if (printed) {
        // Print completed successfully (callback-based, no delay needed)
        if (shouldDisconnect && disconnectAfter) {
          _statusStreamController?.add('Print completed, disconnecting...');
          await disconnect();
        }
        return Result.success();
      } else {
        // Disconnect on failure
        if (shouldDisconnect && disconnectAfter) {
          _statusStreamController?.add('Disconnecting after print failure...');
          await disconnect();
        }
        return Result.error(
          'Print failed after retries',
          code: ErrorCodes.printError,
        );
      }
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
              if (i == maxRetries) return false;
              await Future.delayed(const Duration(seconds: 2));
              continue;
            }
            _statusStreamController?.add('Reconnected successfully');
          } else {
            _statusStreamController?.add('No printer to reconnect to');
            return false;
          }
        }

        final result = await print(data, format: format);

        if (result.success) {
          return true;
        }

        if (i < maxRetries) {
          _statusStreamController
              ?.add('Print failed, retrying... (${i + 1}/$maxRetries)');
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        _statusStreamController?.add('Print error: $e');
        
        if (i < maxRetries) {
          _statusStreamController
              ?.add('Retrying... (${i + 1}/$maxRetries)');
          await Future.delayed(const Duration(seconds: 2));
        } else {
          _statusStreamController
              ?.add('Print failed after $maxRetries attempts');
          return false;
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
          readiness.hasMedia = ParserUtil.hasMedia(readiness.mediaStatus);
          if (readiness.hasMedia == false) {
            readiness.warnings.add('Media not ready: ${readiness.mediaStatus}');
          }
        }

        // Check head latch
        readiness.headStatus = await _doGetSetting('head.latch');
        if (readiness.headStatus != null) {
          readiness.headClosed = ParserUtil.isHeadClosed(readiness.headStatus);
          if (readiness.headClosed == false) {
            readiness.errors.add('Print head is open');
          }
        }

        // Check pause status
        readiness.pauseStatus = await _doGetSetting('device.pause');
        if (readiness.pauseStatus != null) {
          readiness.isPaused = ParserUtil.toBool(readiness.pauseStatus);
          if (readiness.isPaused == true) {
            readiness.warnings.add('Printer is paused');
          }
        }

        // Check for errors
        readiness.hostStatus = await _doGetSetting('device.host_status');
        if (readiness.hostStatus != null) {
          if (!ParserUtil.isStatusOk(readiness.hostStatus)) {
            final errorMsg =
                ParserUtil.parseErrorFromStatus(readiness.hostStatus) ??
                    'Printer error: ${readiness.hostStatus}';
            readiness.errors.add(errorMsg);
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
    _discoveryTimer?.cancel();
    _printer?.dispose();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _devicesStreamController?.close();
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
  
  // ===== Internal helper methods =====

  Future<String?> _doGetSetting(String setting) async {
    try {
      // Use the getSetting method from ZebraPrinter
      final value = await _printer!.getSetting(setting);
      if (value != null && value.isNotEmpty) {
        // Parse the response using our SGD parser
        return ZebraSGDCommands.parseResponse(value);
      }
      return null;
    } catch (e) {
      _statusStreamController?.add('Failed to get setting $setting: $e');
      return null;
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

  /// Run comprehensive diagnostics on the printer
  Future<Result<Map<String, dynamic>>> runDiagnostics() async {
    await _ensureInitialized();

    final diagnostics = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'connected': false,
      'printerInfo': {},
      'status': {},
      'settings': {},
      'errors': [],
      'recommendations': [],
    };

    try {
      // Check connection
      if (connectedPrinter == null) {
        diagnostics['errors'].add('No printer connected');
        diagnostics['recommendations'].add('Connect to a printer first');
        return Result.success(diagnostics);
      }

      diagnostics['connected'] = await _verifyConnection();
      diagnostics['printerInfo'] = {
        'name': connectedPrinter!.name,
        'address': connectedPrinter!.address,
        'isWifi': connectedPrinter!.isWifi,
      };

      if (!diagnostics['connected']) {
        diagnostics['errors'].add('Connection lost');
        diagnostics['recommendations'].add('Reconnect to the printer');
        return Result.success(diagnostics);
      }

      // Get comprehensive status
      _statusStreamController?.add('Running comprehensive diagnostics...');

      // Basic status checks
      final statusChecks = {
        'device.host_status': 'Host Status',
        'media.status': 'Media Status',
        'head.latch': 'Head Status',
        'device.pause': 'Pause Status',
        'odometer.total_print_length': 'Total Print Length',
        'sensor.peeler': 'Peeler Status',
        'device.languages': 'Printer Language',
        'device.unique_id': 'Device ID',
        'device.product_name': 'Product Name',
        'appl.name': 'Firmware Version',
        'media.type': 'Media Type',
        'print.tone': 'Print Darkness',
        'ezpl.print_width': 'Print Width',
        'zpl.label_length': 'Label Length',
      };

      for (final entry in statusChecks.entries) {
        try {
          final value = await _doGetSetting(entry.key);
          if (value != null) {
            diagnostics['status'][entry.value] = value;
          }
        } catch (e) {
          // Continue with other checks
        }
      }

      // Analyze results and provide recommendations
      _analyzeDiagnostics(diagnostics);

      _statusStreamController?.add('Diagnostics complete');
      return Result.success(diagnostics);
    } catch (e, stack) {
      diagnostics['errors'].add('Diagnostic error: $e');
      return Result.error(
        'Failed to run diagnostics: $e',
        code: ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }

  void _analyzeDiagnostics(Map<String, dynamic> diagnostics) {
    final status = diagnostics['status'] as Map<String, dynamic>;
    final recommendations = diagnostics['recommendations'] as List;
    final errors = diagnostics['errors'] as List;

    // Check host status
    final hostStatus = status['Host Status']?.toString().toLowerCase();
    if (hostStatus != null && !hostStatus.contains('ok')) {
      errors.add('Printer reports error: $hostStatus');
      recommendations.add('Check printer display for error details');
    }

    // Check media
    final mediaStatus = status['Media Status']?.toString().toLowerCase();
    if (mediaStatus != null &&
        !mediaStatus.contains('ok') &&
        !mediaStatus.contains('ready')) {
      errors.add('Media issue: $mediaStatus');
      recommendations.add('Check paper/labels are loaded correctly');
    }

    // Check head
    final headStatus = status['Head Status']?.toString().toLowerCase();
    if (headStatus != null &&
        !headStatus.contains('ok') &&
        !headStatus.contains('closed')) {
      errors.add('Print head is open');
      recommendations.add('Close the print head');
    }

    // Check pause
    final pauseStatus = status['Pause Status']?.toString().toLowerCase();
    if (pauseStatus == 'true' || pauseStatus == '1' || pauseStatus == 'on') {
      errors.add('Printer is paused');
      recommendations.add('Unpause the printer (can be auto-corrected)');
    }

    // Check language
    final language = status['Printer Language']?.toString().toLowerCase();
    if (language != null) {
      if (language.contains('zpl')) {
        status['Language Mode'] = 'ZPL';
      } else if (language.contains('line_print') || language.contains('cpcl')) {
        status['Language Mode'] = 'CPCL/Line Print';
      }
    }

    // If no specific errors found but printer won't print
    if (errors.isEmpty && diagnostics['connected'] == true) {
      recommendations.add('Try power cycling the printer');
      recommendations.add('Check printer queue on the device');
      recommendations.add('Verify print data format matches printer language');
      recommendations.add('Try a factory reset if issues persist');
    }
  }
}

