import 'dart:async';
import 'package:zebrautil/zebra_printer.dart';
import 'package:zebrautil/zebra_util.dart';

/// A simplified service for Zebra printer operations.
/// Provides a clean async/await API with proper error handling.
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

    _printer = await ZebraUtil.getPrinterInstance(
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

      await _printer!.connectToPrinter(address);

      // Wait a bit for connection to establish
      await Future.delayed(const Duration(milliseconds: 1000));

      final isConnected = await _printer!.isPrinterConnected();

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
      await _printer!.disconnect();
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
      
      // Auto-detect format if not specified
      if (format == null) {
        if (data.trim().startsWith("^XA")) {
          format = PrintFormat.ZPL;
        } else if (data.trim().startsWith("!")) {
          format = PrintFormat.CPCL;
        } else {
          format = PrintFormat.ZPL; // Default to ZPL
        }
      }

      // Send printer configuration based on format
      if (format == PrintFormat.ZPL) {
        // Ensure printer is in ZPL mode
        _statusStreamController?.add('Setting ZPL mode...');
        // Send ZPL mode command
        await _sendCommand("! U1 setvar \"device.languages\" \"zpl\"");
        await Future.delayed(const Duration(milliseconds: 200));
      } else if (format == PrintFormat.CPCL) {
        // Ensure printer is in CPCL/Line Print mode
        _statusStreamController?.add('Setting CPCL mode...');
        // Some printers use "line_print", others use "cpcl"
        await _sendCommand("! U1 setvar \"device.languages\" \"line_print\"");
        await Future.delayed(const Duration(milliseconds: 200));
      }

      await _printer!.print(data: data);
      
      // Give printer time to process
      await Future.delayed(const Duration(milliseconds: 500));
      
      _statusStreamController?.add('Print sent successfully');
      return true;
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
  /// If address is provided, connects to that printer
  /// If not, uses the first discovered printer (or prompts if multiple)
  Future<bool> autoPrint(String data,
      {String? address, PrintFormat? format}) async {
    await _ensureInitialized();

    try {
      // If already connected to the right printer, just print
      if (connectedPrinter != null &&
          (address == null || connectedPrinter!.address == address)) {
        _statusStreamController?.add('Using existing connection');
        return await print(data, format: format);
      }

      // Disconnect from current printer if needed
      if (connectedPrinter != null) {
        _statusStreamController?.add('Disconnecting from current printer...');
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // If no address provided, discover printers
      if (address == null) {
        _statusStreamController?.add('Discovering printers...');
        final printers = await discoverPrinters(
          timeout: const Duration(seconds: 5),
        );

        if (printers.isEmpty) {
          _statusStreamController?.add('No printers found');
          return false;
        }

        // If only one printer, use it
        if (printers.length == 1) {
          address = printers.first.address;
          _statusStreamController
              ?.add('Found one printer: ${printers.first.name}');
        } else {
          // Multiple printers - need user to select
          _statusStreamController
              ?.add('Multiple printers found - please select one');
          return false;
        }
      }

      // Connect to the printer
      _statusStreamController?.add('Connecting to printer...');
      final connected = await connect(address!);

      if (!connected) {
        _statusStreamController?.add('Failed to connect');
        return false;
      }

      // Print the data
      final printed = await print(data, format: format);

      // Disconnect after printing
      _statusStreamController?.add('Disconnecting...');
      await disconnect();

      return printed;
    } catch (e) {
      _statusStreamController?.add('Auto-print error: $e');
      return false;
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
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _devicesStreamController?.close();
    _connectionStreamController?.close();
    _statusStreamController?.close();
  }
}
