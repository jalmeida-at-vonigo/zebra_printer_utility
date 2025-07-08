import 'dart:async';
import 'package:zebrautil/zebrautil.dart';

/// Simple static API for Zebra printer operations.
///
/// Example usage:
/// ```dart
/// // Discover printers
/// final printers = await Zebra.discoverPrinters();
///
/// // Connect to a printer
/// final connected = await Zebra.connect(printers.first.address);
///
/// // Print ZPL data
/// if (connected) {
///   await Zebra.print('^XA^FO50,50^ADN,36,20^FDHello World^FS^XZ');
/// }
///
/// // Disconnect when done
/// await Zebra.disconnect();
/// ```
class Zebra {
  static final _manager = ZebraPrinterManager();
  static bool _initialized = false;

  /// Public getter for the singleton ZebraPrinterManager
  static ZebraPrinterManager get manager => _manager;

  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      try {
        await _manager.initialize();
        _initialized = true;
      } catch (e, stack) {
        // Log the error but don't let it propagate as an unhandled exception
        print('Error initializing Zebra manager: $e');
        print('Stack trace: $stack');
        // Re-throw as a Result.error to be handled by the calling code
        throw Exception('Failed to initialize Zebra manager: $e');
      }
    }
  }

  /// Stream of discovered devices
  static Future<Stream<List<ZebraDevice>>> get devices async {
    await _ensureInitialized();
    return _manager.discovery.devices;
  }

  /// Stream of current connection state
  static Future<Stream<ZebraDevice?>> get connection async {
    await _ensureInitialized();
    return _manager.connection;
  }

  /// Stream of status messages
  static Future<Stream<String>> get status async {
    _ensureInitialized();
    return _manager.status;
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

  /// Discover available printers
  ///
  /// This will scan for both Bluetooth and Network printers.
  /// On iOS, Bluetooth printers must be paired in Settings first.
  ///
  /// Returns a Result with list of discovered [ZebraDevice] objects.
  static Future<Result<List<ZebraDevice>>> discoverPrinters({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await _ensureInitialized();
    return await _manager.discovery.discoverPrinters(timeout: timeout);
  }

  /// Stop printer discovery
  static Future<void> stopDiscovery() async {
    await _ensureInitialized();
    await _manager.discovery.stopDiscovery();
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
  static Future<Stream<List<ZebraDevice>>> discoverPrintersStream({
    Duration timeout = const Duration(seconds: 10),
    int? stopAfterCount,
    bool stopOnFirstPrinter = false,
    bool includeWifi = true,
    bool includeBluetooth = true,
  }) async {
    await _ensureInitialized();
    return _manager.discovery.discoverPrintersStream(
      timeout: timeout,
      stopAfterCount: stopAfterCount,
      stopOnFirstPrinter: stopOnFirstPrinter,
      includeWifi: includeWifi,
      includeBluetooth: includeBluetooth,
    );
  }

  /// Connect to a printer by address
  ///
  /// Returns Result indicating success or failure.
  static Future<Result<void>> connect(String address) async {
    await _ensureInitialized();
    return await _manager.connect(address);
  }

  /// Disconnect from current printer
  static Future<Result<void>> disconnect() async {
    await _ensureInitialized();
    return await _manager.disconnect();
  }

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
  static Future<Result<void>> print(String data) async {
    await _ensureInitialized();
    return await _manager.print(data);
  }

  /// Smart print with comprehensive event system and automatic recovery
  Stream<PrintEvent> smartPrint(
    String data, {
    ZebraDevice? device,
    int maxAttempts = 3,
    Duration timeout = const Duration(seconds: 60),
  }) {
    return _manager.smartPrint(
      data,
      device: device,
      maxAttempts: maxAttempts,
      timeout: timeout,
    );
  }

  /// Cancel the current smart print operation
  void cancelSmartPrint() {
    _manager.cancelSmartPrint();
  }

  /// Get printer status
  static Future<Result<Map<String, dynamic>>> getPrinterStatus() async {
    await _ensureInitialized();
    return await _manager.getPrinterStatus();
  }

  /// Get detailed printer status with recommendations
  static Future<Result<Map<String, dynamic>>> getDetailedPrinterStatus() async {
    await _ensureInitialized();
    return await _manager.getDetailedPrinterStatus();
  }

  /// Get a printer setting
  static Future<String?> getSetting(String setting) async {
    await _ensureInitialized();
    return await _manager.getSetting(setting);
  }

  /// Set a printer setting
  static void setSetting(String setting, String value) {
    _manager.setSetting(setting, value);
  }

  /// Check if a printer is currently connected
  static Future<bool> isConnected() async {
    await _ensureInitialized();
    return await _manager.isConnected();
  }

  /// Rotate print orientation (for ZPL)
  static void rotate() {
    _manager.rotate();
  }

  /// Get the smart print manager for advanced workflows
  static SmartPrintManager get smartPrintManager {
    _ensureInitialized();
    return _manager.smartPrintManager;
  }

  /// Dispose of resources
  static void dispose() {
    _manager.dispose();
    _initialized = false;
  }
}
