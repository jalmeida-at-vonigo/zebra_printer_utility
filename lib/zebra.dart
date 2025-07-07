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
  static final _service = ZebraPrinterService();
  static bool _initialized = false;

  static ZebraDevice? _savedPrinterToUseOnSimplified;

  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      try {
        await _service.initialize();
        _initialized = true;
      } catch (e, stack) {
        // Log the error but don't let it propagate as an unhandled exception
        print('Error initializing Zebra service: $e');
        print('Stack trace: $stack');
        // Re-throw as a Result.error to be handled by the calling code
        throw Exception('Failed to initialize Zebra service: $e');
      }
    }
  }

  /// Stream of discovered devices
  static Future<Stream<List<ZebraDevice>>> get devices async {
    await _ensureInitialized();
    return _service.discovery.devices;
  }

  /// Stream of current connection state
  static Future<Stream<ZebraDevice?>> get connection async {
    await _ensureInitialized();
    return _service.connection;
  }

  /// Stream of status messages
  static Future<Stream<String>> get status async {
    _ensureInitialized();
    return _service.status;
  }

  /// Currently connected printer
  static ZebraDevice? get connectedPrinter => _service.connectedPrinter;

  /// List of discovered printers
  static List<ZebraDevice> get discoveredPrinters =>
      _service.discoveredPrinters;

  /// Whether discovery is currently active
  static bool get isScanning => _service.discovery.isScanning;

  /// Discovery service for direct access to discovery operations
  static ZebraPrinterDiscovery get discovery => _service.discovery;

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
    return await _service.discovery.discoverPrinters(timeout: timeout);
  }

  /// Stop printer discovery
  static Future<void> stopDiscovery() async {
    await _ensureInitialized();
    await _service.discovery.stopDiscovery();
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
    return _service.discovery.discoverPrintersStream(
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
    return await _service.connect(address);
  }

  /// Disconnect from current printer
  static Future<Result<void>> disconnect() async {
    await _ensureInitialized();
    return await _service.disconnect();
  }

  static Future<Result<void>> printCPCLDirect(String data) async {
    await _ensureInitialized();
    return await _service.printCPCLDirect(data);
  }

  /// Print data to the connected printer
  ///
  /// Returns Result indicating success or failure.
  ///
  /// [format] specifies the print format (ZPL or CPCL). If not provided,
  /// it will be auto-detected based on the data.
  ///
  /// [clearBufferFirst] if true, clears the printer buffer before printing
  /// to ensure no pending data interferes with the print job.
  ///
  /// [readinessOptions] options for printer readiness preparation. If not provided,
  /// defaults to ReadinessOptions.forPrinting() which includes buffer clearing and
  /// language switching for reliable printing.
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
      {PrintFormat? format,
      bool clearBufferFirst = false,
      ReadinessOptions? readinessOptions}) async {
    await _ensureInitialized();

    // Convert clearBufferFirst to ReadinessOptions if needed
    ReadinessOptions? effectiveOptions = readinessOptions;
    if (clearBufferFirst && readinessOptions == null) {
      effectiveOptions = ReadinessOptions.forPrinting();
    }

    return await _service.print(data, readinessOptions: effectiveOptions);
  }

  /// Auto-print workflow: automatically handles connection and printing
  ///
  /// If [address] is provided, connects to that specific printer.
  /// If not provided and only one printer is found, uses that printer.
  /// If multiple printers are found, returns error (user must select).
  ///
  /// [format] specifies the print format (ZPL or CPCL). If not provided,
  /// it will be auto-detected based on the data.
  ///
  /// [printCompletionDelay] specifies how long to wait after print callback
  /// before disconnecting. Default is 1000ms. This prevents the last line
  /// from being cut off on some printers.
  ///
  /// The workflow:
  /// 1. Discover printers (if needed)
  /// 2. Connect to printer
  /// 3. Configure printer for the specified format
  /// 4. Print the data
  /// 5. Wait for print completion
  /// 6. Disconnect
  ///
  /// Returns Result indicating success or failure.
  static Future<Result<void>> autoPrint(String data,
      {ZebraDevice? printer,
      String? address,
      PrintFormat? format,
      int maxRetries = 3,
      bool verifyConnection = true,
      bool disconnectAfter = true,
      ReadinessOptions? readinessOptions,
      Duration? printCompletionDelay}) async {
    await _ensureInitialized();

    // Use provided readinessOptions or default to comprehensive
    final effectiveOptions =
        readinessOptions ?? ReadinessOptions.comprehensive();

    return await _service.autoPrint(data,
        printer: printer,
        address: address,
        format: format,
        maxRetries: maxRetries,
        verifyConnection: verifyConnection,
        disconnectAfter: disconnectAfter,
        readinessOptions: effectiveOptions,
        printCompletionDelay: printCompletionDelay);
  }

  /// Get available printers for selection
  static Future<List<ZebraDevice>> getAvailablePrinters() async {
    await _ensureInitialized();
    return await _service.getAvailablePrinters();
  }

  /// Calibrate the connected printer
  ///
  /// This will perform media calibration on the printer.
  static Future<Result<void>> calibrate() async {
    await _ensureInitialized();
    return await _service.calibrate();
  }

  /// Set printer darkness/density
  ///
  /// [darkness] should be between -30 and 30.
  static Future<Result<void>> setDarkness(int darkness) async {
    await _ensureInitialized();
    return await _service.setDarkness(darkness);
  }

  /// Set media type
  static Future<Result<void>> setMediaType(EnumMediaType type) async {
    await _ensureInitialized();
    return await _service.setMediaType(type);
  }

  /// Check if a printer is currently connected
  static Future<bool> isConnected() async {
    await _ensureInitialized();
    return await _service.isConnected();
  }

  /// Rotate print orientation
  static void rotate() {
    _service.rotate();
  }

  /// Run comprehensive diagnostics on the connected printer
  static Future<Result<Map<String, dynamic>>> runDiagnostics() async {
    await _ensureInitialized();
    return await _service.runDiagnostics();
  }

  /// Printer readiness manager for advanced state/readiness/buffer operations
  static PrinterReadinessManager get printerReadinessManager =>
      PrinterReadinessManager(
        printer: _service.printer!,
        statusCallback: (msg) => _service.statusStreamController?.add(msg),
      );

  /// Simplified print workflow: handles discovery, connection, and printing in a single call
  ///
  /// This method handles the complete workflow:
  /// 1. If no saved printer exists, discovers paired printers and saves the first one
  /// 2. Ensures connection to the printer (checks if already connected)
  /// 3. Prints the data in the specified format
  ///
  /// [data] is the data to print
  /// [format] specifies the print format (ZPL or CPCL). If not provided, auto-detected
  /// [address] specific printer address to use (optional)
  /// [timeout] specifies how long to scan for printers if discovery is needed
  /// [disconnectAfter] whether to disconnect after printing (default: false to maintain connection)
  ///
  /// Returns Result indicating success or failure.
  static Future<Result<void>> simplifiedPrint(
    String data, {
    PrintFormat? format,
    String? address,
    Duration timeout = const Duration(seconds: 10),
    bool disconnectAfter = false,
  }) async {
    await _ensureInitialized();

    try {
      // Step 1: Get or discover a printer
      ZebraDevice? printerToUse = _savedPrinterToUseOnSimplified;

      if (printerToUse == null ||
          (address != null && printerToUse.address != address)) {
        // If we have a different printer, disconnect first
        if (printerToUse != null) {
          await disconnect();
          await Future.delayed(const Duration(milliseconds: 250));
        }

        // Discover paired printers
        final discoveryResult = await discoverPrinters(timeout: timeout);
        if (!discoveryResult.success) {
          return Result.error(
              'Failed to discover printers: ${discoveryResult.error?.message}');
        }

        final printers = discoveryResult.data!;
        if (printers.isEmpty) {
          return Result.error(
              'No paired printers found. Please pair a printer in Settings first.');
        }

        // Find the target printer
        printerToUse = address != null
            ? printers
                .where((printer) => printer.address == address)
                .firstOrNull
            : printers.first;

        if (printerToUse == null) {
          return Result.error('Specified printer not found: $address');
        }

        _savedPrinterToUseOnSimplified = printerToUse;
      }

      // Step 2: Check if already connected to the target printer
      final isConnected = await _service.isConnected();
      final connectedPrinter = _service.connectedPrinter;

      bool needsConnection =
          !isConnected || connectedPrinter?.address != printerToUse.address;

      if (needsConnection) {
        // Connect to the printer
        final connectResult = await connect(printerToUse.address);
        if (!connectResult.success) {
          return Result.error(
              'Failed to connect to printer: ${connectResult.error?.message}');
        }
        // Small delay after connection to ensure stability
        await Future.delayed(const Duration(milliseconds: 250));
      }

      // Step 3: Print the data
      final printResult = await print(data, format: format);
      if (!printResult.success) {
        return Result.error('Failed to print: ${printResult.error?.message}');
      }

      // Step 4: Disconnect if requested
      if (disconnectAfter) {
        await disconnect();
      }

      return Result.success();
    } catch (e) {
      return Result.error('Simplified print failed: $e');
    }
  }
}
