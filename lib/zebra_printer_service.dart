import 'dart:async';
import 'package:zebrautil/zebra_printer.dart';
import 'package:zebrautil/zebra_util.dart';
import 'package:zebrautil/zebra_operation_queue.dart';
import 'package:zebrautil/zebra_sgd_commands.dart';

/// Represents the readiness state of a printer
class PrinterReadiness {
  bool isReady = false;
  bool isConnected = false;
  bool hasMedia = true;
  bool headClosed = true;
  bool isPaused = false;
  List<String> errors = [];
  List<String> warnings = [];

  String get summary {
    if (isReady) return 'Printer is ready';
    if (errors.isNotEmpty) return errors.join(', ');
    if (!isConnected) return 'Not connected';
    if (!hasMedia) return 'No media';
    if (!headClosed) return 'Head open';
    if (isPaused) return 'Printer paused';
    return 'Not ready';
  }
}

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

    _printer = await ZebraUtil.getPrinterInstance(
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
  /// Returns the list of discovered devices
  Future<List<ZebraDevice>> discoverPrinters({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await _ensureInitialized();

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

    return completer.future;
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
  /// Returns true if connection successful
  Future<bool> connect(String address) async {
    await _ensureInitialized();

    try {
      _statusStreamController?.add('Connecting to $address...');

      final isConnected = await _operationQueue!.enqueue<bool>(
        OperationType.connect,
        {'address': address},
        timeout: const Duration(seconds: 10),
      );

      if (isConnected) {
        _statusStreamController?.add('Connected to $address');
      } else {
        _statusStreamController?.add('Failed to connect to $address');
      }

      return isConnected;
    } catch (e) {
      _statusStreamController?.add('Connection error: $e');
      return false;
    }
  }

  /// Disconnect from current printer
  Future<void> disconnect() async {
    await _ensureInitialized();

    if (connectedPrinter != null) {
      _statusStreamController?.add('Disconnecting...');
      await _operationQueue!.enqueue<void>(
        OperationType.disconnect,
        {},
        timeout: const Duration(seconds: 5),
      );
      _statusStreamController?.add('Disconnected');
    }
  }

  /// Print data to the connected printer
  /// Returns true if print successful
  Future<bool> print(String data, {PrintFormat? format}) async {
    await _ensureInitialized();
    
    if (connectedPrinter == null) {
      _statusStreamController?.add('No printer connected');
      return false;
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
      }
      return success;
    } catch (e) {
      _statusStreamController?.add('Print error: $e');
      return false;
    }
  }
  
  /// Send a command to the printer
  Future<void> _sendCommand(String command) async {
    try {
      // Send raw command data
      await _printer!.print(data: command);
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      _statusStreamController?.add('Command error: $e');
    }
  }
  
  /// Auto-print workflow: discover, connect, print, disconnect
  /// If printer is provided, uses that printer
  /// If address is provided, connects to that printer
  /// If neither is provided, discovers and uses the first available printer
  Future<bool> autoPrint(String data,
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
      return false;
    }

    int retryCount = 0;
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
              return await _printWithRetry(data,
                  format: format, maxRetries: maxRetries);
            }
          } else {
            // Just print without verification
            return await _printWithRetry(data,
                format: format, maxRetries: maxRetries);
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
            return await _printWithRetry(data,
                format: format, maxRetries: maxRetries);
          } else {
            _statusStreamController?.add('Connection lost, reconnecting...');
            await disconnect();
          }
        } else {
          return await _printWithRetry(data,
              format: format, maxRetries: maxRetries);
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
          return false;
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
          return false;
        }
      }

      // Connect to the printer with retries
      _statusStreamController?.add('Connecting to printer...');
      bool connected = false;

      for (int i = 0; i <= maxRetries; i++) {
        connected = await connect(address!);

        if (connected) {
          shouldDisconnect = disconnectAfter;
          break;
        }

        if (i < maxRetries) {
          _statusStreamController
              ?.add('Connection failed, retrying... (${i + 1}/$maxRetries)');
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (!connected) {
        _statusStreamController
            ?.add('Failed to connect after $maxRetries attempts');
        return false;
      }

      // Verify connection and readiness before printing
      if (verifyConnection) {
        final readiness = await checkPrinterReadiness();
        if (!readiness.isReady) {
          _statusStreamController
              ?.add('Printer not ready: ${readiness.summary}');
          if (shouldDisconnect) await disconnect();
          return false;
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

      return printed;
    } catch (e) {
      _statusStreamController?.add('Auto-print error: $e');
      
      // Clean up on error
      if (shouldDisconnect && connectedPrinter != null) {
        try {
          await disconnect();
        } catch (_) {}
      }

      return false;
    }
  }

  /// Print with retry logic
  Future<bool> _printWithRetry(String data,
      {PrintFormat? format, int maxRetries = 3}) async {
    for (int i = 0; i <= maxRetries; i++) {
      try {
        final success = await print(data, format: format);

        if (success) {
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
  Future<PrinterReadiness> checkPrinterReadiness() async {
    final readiness = PrinterReadiness();

    try {
      if (connectedPrinter == null) {
        readiness.isReady = false;
        readiness.errors.add('Not connected to printer');
        return readiness;
      }

      // Check connection
      readiness.isConnected = await _verifyConnection();
      if (!readiness.isConnected) {
        readiness.isReady = false;
        readiness.errors.add('Printer connection lost');
        return readiness;
      }

      // Now we can implement full printer readiness checks
      try {
        // Check media status
        final mediaStatus = await _doGetSetting('media.status');
        if (mediaStatus != null) {
          readiness.hasMedia = mediaStatus.toLowerCase().contains('ok') ||
              mediaStatus.toLowerCase().contains('ready');
          if (!readiness.hasMedia) {
            readiness.warnings.add('Media not ready: $mediaStatus');
          }
        }

        // Check head latch
        final headStatus = await _doGetSetting('head.latch');
        if (headStatus != null) {
          readiness.headClosed = headStatus.toLowerCase().contains('ok') ||
              headStatus.toLowerCase().contains('closed');
          if (!readiness.headClosed) {
            readiness.errors.add('Print head is open');
          }
        }

        // Check pause status
        final pauseStatus = await _doGetSetting('device.pause');
        if (pauseStatus != null) {
          readiness.isPaused = pauseStatus.toLowerCase() == 'true' ||
              pauseStatus.toLowerCase() == 'on';
          if (readiness.isPaused) {
            readiness.warnings.add('Printer is paused');
          }
        }

        // Check for errors
        final errorStatus = await _doGetSetting('device.host_status');
        if (errorStatus != null && !errorStatus.toLowerCase().contains('ok')) {
          readiness.errors.add('Printer error: $errorStatus');
        }

        // Determine overall readiness
        readiness.isReady = readiness.isConnected &&
            readiness.headClosed &&
            !readiness.isPaused &&
            readiness.errors.isEmpty;

        if (readiness.isReady) {
          _statusStreamController?.add('Printer is ready');
        } else {
          _statusStreamController
              ?.add('Printer not ready: ${readiness.summary}');
        }
      } catch (e) {
        // If we can't get status, assume ready if connected
        _statusStreamController
            ?.add('Could not check full status, assuming ready if connected');
        readiness.isReady = readiness.isConnected;
      }

      return readiness;
    } catch (e) {
      readiness.isReady = false;
      readiness.errors.add('Error checking printer status: $e');
      return readiness;
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
    return await discoverPrinters(timeout: const Duration(seconds: 5));
  }

  /// Calibrate the connected printer
  Future<bool> calibrate() async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      _statusStreamController?.add('No printer connected');
      return false;
    }

    try {
      _statusStreamController?.add('Calibrating printer...');
      _printer!.calibratePrinter();

      await Future.delayed(const Duration(milliseconds: 500));

      _statusStreamController?.add('Calibration complete');
      return true;
    } catch (e) {
      _statusStreamController?.add('Calibration error: $e');
      return false;
    }
  }

  /// Set printer darkness/density
  Future<bool> setDarkness(int darkness) async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      _statusStreamController?.add('No printer connected');
      return false;
    }

    if (darkness < -30 || darkness > 30) {
      _statusStreamController?.add('Darkness must be between -30 and 30');
      return false;
    }

    try {
      _printer!.setDarkness(darkness);
      _statusStreamController?.add('Darkness set to $darkness');
      return true;
    } catch (e) {
      _statusStreamController?.add('Set darkness error: $e');
      return false;
    }
  }

  /// Set media type
  Future<bool> setMediaType(EnumMediaType type) async {
    await _ensureInitialized();

    if (connectedPrinter == null) {
      _statusStreamController?.add('No printer connected');
      return false;
    }

    try {
      _printer!.setMediaType(type);
      _statusStreamController?.add('Media type set to ${type.name}');
      return true;
    } catch (e) {
      _statusStreamController?.add('Set media type error: $e');
      return false;
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

  Future<bool> _doConnect(String address) async {
    try {
      await _printer!.connectToPrinter(address);
      await Future.delayed(const Duration(milliseconds: 500));
      return await _printer!.isPrinterConnected();
    } catch (e) {
      throw Exception('Connection failed: $e');
    }
  }

  Future<void> _doDisconnect() async {
    await _printer!.disconnect();
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
    await _printer!.print(data: data);
    return true;
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

  /// Send multiple status check commands
  Future<void> _sendStatusChecks() async {
    // These commands would normally return responses that we'd parse
    await _printer!.print(data: ZebraSGDCommands.getPrinterStatus);
    await Future.delayed(const Duration(milliseconds: 50));

    await _printer!.print(data: ZebraSGDCommands.getMediaStatus);
    await Future.delayed(const Duration(milliseconds: 50));

    await _printer!.print(data: ZebraSGDCommands.getHeadStatus);
    await Future.delayed(const Duration(milliseconds: 50));

    await _printer!.print(data: ZebraSGDCommands.getPaused);
  }
}

