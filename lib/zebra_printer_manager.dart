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
///
/// It does NOT contain workflow logic - that belongs in SmartPrintManager
/// and other workflow managers.
class ZebraPrinterManager {
  ZebraPrinter? _printer;
  ZebraController? _controller;
  ZebraPrinterDiscovery? _discovery;

  StreamController<ZebraDevice?>? _connectionStreamController;
  StreamController<String>? _statusStreamController;
  final Logger _logger = Logger.withPrefix('ZebraPrinterManager');
  
  // Smart print manager instance
  SmartPrintManager? _smartPrintManager;

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

  /// Primitive: Print data to the connected printer
  /// This only sends data - no workflow logic, delays, or status checks
  Future<Result<void>> print(String data) async {
    _logger.info('Manager: Sending print data to printer');
    await _ensureInitialized();

    if (connectedPrinter == null) {
      _logger.error('Manager: Print operation failed - No printer connected');
      _statusStreamController?.add('No printer connected');
      return Result.errorCode(
        ErrorCodes.notConnected,
      );
    }

    try {
      final printResult = await _printer!.print(data: data);
      if (printResult.success) {
        _logger.info('Manager: Print data sent successfully');
        _statusStreamController?.add('Print data sent successfully');
        return printResult;
      } else {
        _logger.error(
            'Manager: Print operation failed: ${printResult.error?.message}');
        return Result.errorCode(
          ErrorCodes.printError,
        );
      }
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

  /// Primitive: Wait for print completion with timeout
  Future<Result<bool>> waitForPrintCompletion({int timeoutSeconds = 30}) async {
    _logger.info(
        'Manager: Waiting for print completion (timeout: ${timeoutSeconds}s)');
    await _ensureInitialized();

    try {
      if (_printer == null) {
        return Result.errorCode(
          ErrorCodes.notConnected,
        );
      }

      final completionCommand =
          CommandFactory.createWaitForPrintCompletionCommand(
        _printer!,
        timeoutSeconds: timeoutSeconds,
      );
      final result = await completionCommand.execute();

      if (result.success) {
        final success = result.data ?? false;
        if (success) {
          _logger.info('Manager: Print completion successful');
          return Result.success(true);
        } else {
          _logger.warning(
              'Manager: Print completion failed - hardware issues detected');
          return Result.success(false);
        }
      } else {
        _logger.error(
            'Manager: Failed to wait for print completion - ${result.error?.message}');
        return result.map((data) => data);
      }
    } catch (e, stack) {
      _logger.error('Manager: Error waiting for print completion', e, stack);
      return Result.errorCode(
        ErrorCodes.operationError,
        formatArgs: ['Error waiting for print completion: $e'],
        dartStackTrace: stack,
      );
    }
  }

  /// Primitive: Get setting
  Future<String?> getSetting(String setting) async {
    await _ensureInitialized();
    if (_printer == null) return null;
    return await _printer!.getSetting(setting);
  }

  /// Primitive: Set setting
  void setSetting(String setting, String value) {
    _printer?.setSetting(setting, value);
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

  // ===== SMART PRINT MANAGER INTEGRATION =====

  /// Get or create the smart print manager instance
  SmartPrintManager get smartPrintManager {
    _smartPrintManager ??= SmartPrintManager(this);
    return _smartPrintManager!;
  }

  /// Smart print with comprehensive event system and automatic recovery
  /// Returns a stream of print events for UI updates
  Stream<PrintEvent> smartPrint(
    String data, {
    ZebraDevice? device,
    int maxAttempts = 3,
    Duration timeout = const Duration(seconds: 60),
  }) {
    _logger.info('Manager: Starting smart print operation');
    
    // Start the smart print operation and return the events stream
    smartPrintManager.smartPrint(
      data: data,
      device: device,
      maxAttempts: maxAttempts,
      timeout: timeout,
    );

    return smartPrintManager.eventStream;
  }

  /// Cancel the current smart print operation
  void cancelSmartPrint() {
    _logger.info('Manager: Cancelling smart print operation');
    smartPrintManager.cancel();
  }

  /// Dispose the smart print manager
  void disposeSmartPrintManager() {
    _smartPrintManager = null;
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
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _connectionStreamController?.close();
    _statusStreamController?.close();
    disposeSmartPrintManager();
  }
} 