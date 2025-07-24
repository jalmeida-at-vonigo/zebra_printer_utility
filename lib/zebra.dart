import 'dart:async';
import 'internal/logger.dart';
import 'models/print_event.dart';
import 'models/print_options.dart';
import 'models/result.dart';
import 'models/zebra_device.dart';
import 'smart_print_manager.dart';
import 'zebra_printer.dart';
import 'zebra_printer_discovery.dart';
import 'zebra_printer_manager.dart';

/// Main entry point for Zebra printer operations
///
/// This class provides a unified API for:
/// - Printer discovery and connection
/// - Print operations with smart workflows
/// - Status monitoring and diagnostics
///
/// **Basic Usage:**
/// ```dart
/// // Initialize
/// await Zebra.initialize();
///
/// // Discover printers
/// final devices = await Zebra.discoverPrinters();
///
/// // Connect to a printer
/// await Zebra.connect(devices.first);
///
/// // Print data
/// await Zebra.print('^XA^FO50,50^FDHello World^FS^XZ');
/// ```
///
/// **Smart Print Workflow:**
/// ```dart
/// final events = Zebra.smartPrint(data: zplData);
/// await for (final event in events) {
///   print('Print progress: ${event.type}');
/// }
/// ```
class Zebra {
  static final _manager = ZebraPrinterManager();
  static SmartPrintManager? _smartPrintManager;
  static Result<void>? _initializationResult;
  static final Logger _logger = Logger.withPrefix('Zebra');

  /// Public getter for the singleton ZebraPrinterManager
  /// Use this for advanced operations and direct manager access
  static ZebraPrinterManager get manager => _manager;

  /// Public getter for the singleton SmartPrintManager
  /// Use this for advanced smart print operations
  static Future<Result<SmartPrintManager>> get smartPrintManager async {
    final initResult = await _ensureInitialized();
    if (!initResult.success) {
      return Result.errorFromResult(initResult);
    }
    _smartPrintManager ??= SmartPrintManager(_manager);
    return Result.success(_smartPrintManager!);
  }

  /// Ensures the manager is initialized, returning Result
  static Future<Result<void>> _ensureInitialized() async {
    // Return cached result if already attempted
    if (_initializationResult != null) {
      return _initializationResult!;
    }

    try {
      final result = await _manager.initialize();
      if (result.success) {
        _initializationResult = Result.success();
      } else {
        _initializationResult = Result.errorFromResult(result);
      }
    } catch (e, stack) {
      // Log the error but don't let it propagate as an unhandled exception
      _logger.error('Error initializing Zebra manager: $e', e, stack);
      _initializationResult = Result.error(
        'Failed to initialize Zebra manager: $e',
        code: ErrorCodes.operationError.code,
        dartStackTrace: stack,
      );
    }
    
    return _initializationResult!;
  }

  // ===== STREAMS AND STATE =====

  /// Stream of discovered devices
  static Future<Result<Stream<List<ZebraDevice>>>> get devices async {
    final initResult = await _ensureInitialized();
    if (!initResult.success) {
      return Result.errorFromResult(initResult);
    }
    return Result.success(_manager.discovery.devices);
  }

  /// Stream of current connection state
  static Future<Result<Stream<ZebraDevice?>>> get connection async {
    final initResult = await _ensureInitialized();
    if (!initResult.success) {
      return Result.errorFromResult(initResult);
    }
    return Result.success(_manager.connection);
  }

  /// Stream of status messages
  static Future<Result<Stream<String>>> get status async {
    final initResult = await _ensureInitialized();
    if (!initResult.success) {
      return Result.errorFromResult(initResult);
    }
    return Result.success(_manager.status);
  }

  /// Currently connected printer
  static ZebraDevice? get connectedPrinter => _manager.connectedPrinter;

  /// List of discovered printers
  static List<ZebraDevice> get discoveredPrinters =>
      _manager.discoveredPrinters;

  /// Whether discovery is currently active
  static bool get isScanning => _manager.discovery.isScanning;

  /// Discovery service for direct access to discovery operations
  static ZebraPrinterDiscovery get discovery => _manager.discovery;

  // ===== DISCOVERY OPERATIONS =====

  /// Discover available printers
  ///
  /// This will scan for both Bluetooth and Network printers.
  /// On iOS, Bluetooth printers must be paired in Settings first.
  ///
  /// Returns a Result with list of discovered [ZebraDevice] objects.
  static Future<Result<List<ZebraDevice>>> discoverPrinters({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final initResult = await _ensureInitialized();
    if (!initResult.success) {
      return Result.errorFromResult(initResult);
    }
    return await _manager.discovery.discoverPrinters(timeout: timeout);
  }

  /// Stop printer discovery
  static Future<Result<void>> stopDiscovery() async {
    final initResult = await _ensureInitialized();
    if (!initResult.success) {
      return initResult; // Pass through the initialization error
    }
    await _manager.discovery.stopDiscovery();
    return Result.success();
  }

  /// Discover available printers with streaming approach
  ///
  /// This will scan for both Bluetooth and Network printers and return
  /// a stream of discovered devices as they are found.
  ///
  /// [timeout] specifies how long to scan for printers
  /// [stopAfterCount] stops discovery after finding this many printers
  /// [stopOnFirstPrinter] stops discovery after finding the first printer
  /// [includeWifi] whether to include WiFi/Network printers
  /// [includeBluetooth] whether to include Bluetooth printers
  ///
  /// Returns a Stream of discovered [ZebraDevice] lists.
  static Future<Result<Stream<List<ZebraDevice>>>> discoverPrintersStream({
    Duration timeout = const Duration(seconds: 10),
    int? stopAfterCount,
    bool stopOnFirstPrinter = false,
    bool includeWifi = true,
    bool includeBluetooth = true,
  }) async {
    final initResult = await _ensureInitialized();
    if (!initResult.success) {
      return Result.errorFromResult(initResult);
    }
    final stream = _manager.discovery.discoverPrintersStream(
      timeout: timeout,
      stopAfterCount: stopAfterCount,
      stopOnFirstPrinter: stopOnFirstPrinter,
      includeWifi: includeWifi,
      includeBluetooth: includeBluetooth,
    );
    return Result.success(stream);
  }

  // ===== CONNECTION OPERATIONS =====

  /// Connect to a printer by address
  ///
  /// Returns Result indicating success or failure.
  static Future<Result<void>> connect(String address) async {
    final initResult = await _ensureInitialized();
    if (!initResult.success) {
      return initResult; // Pass through the initialization error
    }
    return await _manager.connect(address);
  }

  /// Disconnect from current printer
  static Future<Result<void>> disconnect() async {
    final initResult = await _ensureInitialized();
    if (!initResult.success) {
      return initResult; // Pass through the initialization error
    }
    return await _manager.disconnect();
  }

  /// Check if a printer is currently connected
  static Future<Result<bool>> isConnected() async {
    final initResult = await _ensureInitialized();
    if (!initResult.success) {
      return Result.errorFromResult(initResult);
    }
    final connected = await _manager.isConnected();
    return Result.success(connected);
  }

  // ===== PRINT OPERATIONS =====

  /// Print data to the connected printer (primitive operation)
  ///
  /// This is a primitive operation that only sends data to the printer.
  /// For complex workflows with status checking, retries, and error handling,
  /// use [smartPrint] instead.
  ///
  /// Returns Result indicating success or failure.
  ///
  /// Example ZPL:
  /// ```
  /// ^XA
  /// ^FO50,50
  /// ^ADN,36,20
  /// ^FDHello World
  /// ^FS
  /// ^XZ
  /// ```
  ///
  /// Example CPCL:
  /// ```
  /// ! 0 200 200 210 1
  /// TEXT 4 0 30 40 Hello World
  /// FORM
  /// PRINT
  /// ```
  static Future<Result<void>> print(String data,
      {PrintOptions? options}) async {
    final initResult = await _ensureInitialized();
    if (!initResult.success) {
      return initResult; // Pass through the initialization error
    }
    return await _manager.print(data, options: options);
  }

  /// Smart print with comprehensive event system and automatic recovery
  ///
  /// This method provides a complete print workflow with:
  /// - Automatic connection management
  /// - Retry logic with exponential backoff
  /// - Real-time progress events
  /// - Error classification and recovery
  /// - Format detection and optimization
  ///
  /// Returns a Stream of [PrintEvent] objects for monitoring progress.
  ///
  /// Example usage:
  /// ```dart
  /// final eventStream = Zebra.smartPrint(
  ///   '^XA^FO50,50^ADN,36,20^FDHello World^FS^XZ',
  ///   maxAttempts: 3,
  ///   timeout: Duration(seconds: 60),
  /// );
  ///
  /// eventStream.listen((event) {
  ///   switch (event.type) {
  ///     case PrintEventType.stepChanged:
  ///       print('Step: ${event.stepInfo?.message}');
  ///       break;
  ///     case PrintEventType.errorOccurred:
  ///       print('Error: ${event.errorInfo?.message}');
  ///       break;
  ///     case PrintEventType.completed:
  ///       print('Print completed successfully');
  ///       break;
  ///   }
  /// });
  /// ```
  static Stream<PrintEvent> smartPrint(
    String data, {
    ZebraDevice? device,
    int maxAttempts = 3,
    PrintOptions? options,
  }) async* {
    // Convert null options to empty instance to avoid ?? operators throughout
    options ??= const PrintOptions();

    final initResult = await _ensureInitialized();
    if (!initResult.success) {
      yield PrintEvent(
        type: PrintEventType.errorOccurred,
        timestamp: DateTime.now(),
        errorInfo: PrintErrorInfo(
          message: initResult.error!.message,
          recoverability: ErrorRecoverability.nonRecoverable,
          errorCode: initResult.error!.code,
        ),
      );
      return;
    }
    final managerResult = await smartPrintManager;
    if (!managerResult.success) {
      yield PrintEvent(
        type: PrintEventType.errorOccurred,
        timestamp: DateTime.now(),
        errorInfo: PrintErrorInfo(
          message: managerResult.error!.message,
          recoverability: ErrorRecoverability.nonRecoverable,
          errorCode: managerResult.error!.code,
        ),
      );
      return;
    }
    // Start the smart print operation
    await managerResult.data!.smartPrint(
      data: data,
      device: device,
      maxAttempts: maxAttempts,
      options: options,
    );
    
    // Stream events from the manager's event stream
    yield* managerResult.data!.eventStream;
  }

  /// Cancel the current smart print operation
  static Future<Result<void>> cancelSmartPrint() async {
    final initResult = await _ensureInitialized();
    if (!initResult.success) {
      return initResult; // Pass through the initialization error
    }
    final managerResult = await smartPrintManager;
    if (!managerResult.success) {
      return Result.errorFromResult(managerResult);
    }
    managerResult.data!.cancel();
    return Result.success();
  }

  // ===== STATUS OPERATIONS =====

  /// Get printer status
  static Future<Result<Map<String, dynamic>>> getPrinterStatus() async {
    final initResult = await _ensureInitialized();
    if (!initResult.success) {
      return Result.errorFromResult(initResult);
    }
    return await _manager.getPrinterStatus();
  }

  /// Get detailed printer status with recommendations
  static Future<Result<Map<String, dynamic>>> getDetailedPrinterStatus() async {
    final initResult = await _ensureInitialized();
    if (!initResult.success) {
      return Result.errorFromResult(initResult);
    }
    return await _manager.getDetailedPrinterStatus();
  }

  // ===== UTILITY OPERATIONS =====

  /// Rotate print orientation (for ZPL)
  static void rotate() {
    _manager.rotate();
  }

  // ===== ADVANCED ACCESS =====

  /// Get the underlying ZebraPrinter instance for advanced operations
  /// Use this when you need direct access to the printer primitives
  static ZebraPrinter? get printer => _manager.printer;

  /// Dispose of resources
  static void dispose() {
    _manager.dispose();
    _smartPrintManager = null;
    _initializationResult = null; // Reset to allow re-initialization
  }
}
