import 'dart:async';
import 'internal/print_data_processor.dart';
import 'models/connection_event.dart';
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
/// **Basic Usage (with global instance):**
/// ```dart
/// // Initialize global instance
/// await Zebra.ensureGlobalInitialized();
/// 
/// // Use the global instance (default printer)
/// final zebra = Zebra.global;
/// final devices = await zebra.discoverPrinters();
/// await zebra.connect(devices.first.address);
/// await zebra.print('^XA^FO50,50^FDHello World^FS^XZ');
/// ```
///
/// **Multi-Printer Usage:**
/// ```dart
/// // Create specific printer instances
/// final zebraA = await Zebra.create();
/// final zebraB = await Zebra.create(printerB);
/// await zebraA.print(dataA);
/// await zebraB.print(dataB);
/// ```
///
/// **Smart Print Workflow:**
/// ```dart
/// await Zebra.ensureGlobalInitialized();
/// final zebra = Zebra.global;
/// final events = zebra.smartPrint(data: zplData);
/// await for (final event in events) {
///   print('Print progress: ${event.type}');
/// }
/// ```
class Zebra {
  /// Private constructor - use create() factory instead
  Zebra._(this.printer) : manager = ZebraPrinterManager(printer: printer) {
    // Create SmartPrintManager with the same manager instance
    smartManager = SmartPrintManager(manager: manager);
    // Create discovery with the printer
    discovery = ZebraPrinterDiscovery(printer: printer);
    // Initialize the manager
    manager.initialize();
  }

  final ZebraPrinter printer;
  final ZebraPrinterManager manager;
  late final SmartPrintManager smartManager;
  late final ZebraPrinterDiscovery discovery;

  // ===== GLOBAL SINGLETON MANAGEMENT =====

  /// Global singleton instance with default printer
  static Zebra? _global;

  /// Sync getter for global instance - throws if not initialized
  static Zebra get global {
    if (_global == null) {
      throw StateError(
          'Zebra.global not initialized. Call Zebra.ensureGlobalInitialized() first.');
    }
    return _global!;
  }
  
  /// Async method to ensure global instance is initialized
  static Future<void> ensureGlobalInitialized() async {
    _global ??= await Zebra.create();
  }

  /// Factory method to create a Zebra instance with a specific printer
  static Future<Zebra> create([ZebraPrinter? printer]) async {
    final p = printer ?? await ZebraPrinter.create();
    return Zebra._(p);
  }


  // ===== STREAMS AND STATE =====

  /// Stream of discovered devices
  Stream<List<ZebraDevice>> get devices => discovery.devices;

  /// Stream of current connection state
  Stream<ZebraDevice?> get connection => manager.connection;

  /// Stream of status messages
  Stream<String> get status => manager.status;

  /// Stream of real-time connection events for immediate UI updates
  Stream<ConnectionEvent> get connectionEvents => manager.connectionEvents;

  /// Currently connected printer
  ZebraDevice? get connectedPrinter => manager.connectedPrinter;

  /// List of discovered printers
  List<ZebraDevice> get discoveredPrinters => manager.discoveredPrinters;

  /// Whether discovery is currently active
  bool get isScanning => discovery.isScanning;

  // ===== DISCOVERY OPERATIONS =====

  /// Discover available printers with streaming approach
  ///
  /// This will scan for both Bluetooth and Network printers and return
  /// a stream of discovered devices as they are found.
  ///
  /// [timeout] specifies how long to scan for printers
  /// [includeWifi] whether to include WiFi/Network printers
  /// [includeBluetooth] whether to include Bluetooth printers
  /// [onWarning] callback for discovery warnings
  ///
  /// Returns a Stream of discovered [ZebraDevice] lists.
  Stream<List<ZebraDevice>> discoverPrintersStream({
    Duration timeout = const Duration(seconds: 10),
    bool includeWifi = true,
    bool includeBluetooth = true,
    void Function({String? phase, String? target, String? message})? onWarning,
  }) {
    return discovery.discoverPrintersStream(
      timeout: timeout,
      includeWifi: includeWifi,
      includeBluetooth: includeBluetooth,
      onWarning: onWarning,
    );
  }

  /// Stop printer discovery
  Future<Result<void>> stopDiscovery() async {
    await discovery.stopDiscovery();
    return Result.success();
  }

  // ===== CONNECTION OPERATIONS =====

  /// Connect to a printer by address
  ///
  /// Returns Result indicating success or failure.
  Future<Result<void>> connect(String address) async {
    return await manager.connect(address);
  }

  /// Disconnect from current printer
  Future<Result<void>> disconnect() async {
    return await manager.disconnect();
  }

  /// Check if a printer is currently connected
  Future<Result<bool>> isPrinterConnected() async {
    final connected = await manager.isPrinterConnected();
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
  Future<Result<void>> print(String data, {PrintOptions? options}) async {
    return await manager.print(data, options: options);
  }

  /// Print processed data to the connected printer (primitive operation)
  ///
  /// This is a primitive operation that sends already processed data to the printer.
  /// The data has already been validated, formatted, and prepared for printing.
  ///
  /// For complex workflows with status checking, retries, and error handling,
  /// use [smartPrintProcessed] instead.
  ///
  /// Returns Result indicating success or failure.
  Future<Result<void>> printWithProcessedData(ProcessedPrintData processedData,
      {PrintOptions? options}) async {
    return await manager.printWithProcessedData(processedData,
        options: options);
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
  /// final eventStream = zebra.smartPrint(
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
  Stream<PrintEvent> smartPrint(
    String data, {
    ZebraDevice? device,
    int maxAttempts = 3,
    PrintOptions? options,
  }) async* {
    // Convert null options to empty instance to avoid ?? operators throughout
    options ??= const PrintOptions();

    // Start the smart print operation
    await smartManager.smartPrint(
      data: data,
      device: device,
      maxAttempts: maxAttempts,
      options: options,
    );
    
    // Stream events from the manager's event stream
    yield* smartManager.eventStream;
  }

  /// Smart print with processed data (avoids redundant processing)
  ///
  /// This method provides the same comprehensive workflow as smartPrint but
  /// accepts already processed print data, avoiding redundant format detection,
  /// validation, and formatting operations.
  ///
  /// Returns a Stream of [PrintEvent] objects for monitoring progress.
  ///
  /// Example usage:
  /// ```dart
  /// // Process data first
  /// final processResult = PrintDataProcessor.process(rawData, PrintFormat.zpl);
  /// if (processResult.success) {
  ///   final eventStream = zebra.smartPrintProcessed(
  ///     processResult.data!,
  ///     maxAttempts: 3,
  ///   );
  ///
  ///   eventStream.listen((event) {
  ///     print('Event: ${event.type}');
  ///   });
  /// }
  /// ```
  Stream<PrintEvent> smartPrintWithProcessedData(
    ProcessedPrintData processedData, {
    ZebraDevice? device,
    int maxAttempts = 3,
    PrintOptions? options,
  }) async* {
    // Convert null options to empty instance to avoid ?? operators throughout
    options ??= const PrintOptions();

    // Start the smart print operation with processed data
    await smartManager.smartPrintWithProcessedData(
      processedData: processedData,
      device: device,
      maxAttempts: maxAttempts,
      options: options,
    );

    // Stream events from the manager's event stream
    yield* smartManager.eventStream;
  }

  /// Cancel the current smart print operation
  Future<Result<void>> cancelSmartPrint() async {
    smartManager.cancel();
    return Result.success();
  }

  // ===== STATUS OPERATIONS =====

  /// Get printer status
  Future<Result<Map<String, dynamic>>> getPrinterStatus() async {
    return await manager.getPrinterStatus();
  }

  /// Get detailed printer status with recommendations
  Future<Result<Map<String, dynamic>>> getDetailedPrinterStatus() async {
    return await manager.getDetailedPrinterStatus();
  }

  // ===== UTILITY OPERATIONS =====

  /// Rotate print orientation (for ZPL)
  void rotate() {
    manager.rotate();
  }

  // ===== ADVANCED ACCESS =====

  /// Get the underlying ZebraPrinter instance for advanced operations
  /// Use this when you need direct access to the printer primitives
  ZebraPrinter get printerInstance => printer;

  /// Dispose of resources
  void dispose() {
    manager.dispose();
    printer.dispose();
  }

  /// Static dispose for global instance
  static void disposeGlobal() {
    _global?.dispose();
    _global = null;
  }


}
