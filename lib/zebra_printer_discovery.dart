import 'dart:async';

import 'internal/logger.dart';
import 'zebrautil.dart';

/// Service for discovering Zebra printers
/// Provides centralized discovery functionality for both Bluetooth and Network printers
///
/// **Error Handling Strategy:**
/// - Discovery methods return Result&lt;T&gt; for operation-level errors
/// - Real-time errors are emitted via the status stream
/// - Native discovery errors are handled by ZebraPrinter event handlers
/// - No constructor-level callbacks - errors are operation-specific
///
/// Note: CommunicationPolicy is handled by ZebraPrinterManager. This service
/// only uses timeout policies for discovery operations.
class ZebraPrinterDiscovery {
  ZebraPrinterDiscovery({
    required ZebraPrinter printer,
  }) : _printer = printer;

  // Private fields
  final ZebraPrinter _printer;
  StreamController<List<ZebraDevice>>? _devicesStreamController;
  StreamController<String>? _statusStreamController;
  // No per-operation log subscription here; status stream already provides public messages
  
  Timer? _discoveryTimer;
  bool _isScanning = false;

  // Logger
  final Logger _logger = Logger.withPrefix('ZebraPrinterDiscovery');

  /// Whether discovery is currently active
  bool get isScanning => _isScanning;

  /// Stream of discovered devices
  Stream<List<ZebraDevice>> get devices =>
      _devicesStreamController?.stream ?? const Stream.empty();

  /// Stream of status messages
  Stream<String> get status =>
      _statusStreamController?.stream ?? const Stream.empty();


  /// Initialize the discovery service
  Future<void> initialize({
    Function(String)? statusCallback,
  }) async {
    if (_devicesStreamController != null) return;

    _logger.info('Initializing ZebraPrinterDiscovery service');
    _devicesStreamController = StreamController<List<ZebraDevice>>.broadcast();
    _statusStreamController = StreamController<String>.broadcast();

    // Hook up status callback if provided
    if (statusCallback != null) {
      _statusStreamController!.stream.listen(statusCallback);
    }

    // Communication policy is now managed by ZebraPrinterManager
    // This class primarily manages the discovery flow
    
    // Pure streaming service - no device collection management
    
    _logger.info('ZebraPrinterDiscovery initialization completed');
  }


  /// Discover available printers with streaming approach
  /// Returns a stream of discovered devices
  Stream<List<ZebraDevice>> discoverPrintersStream({
    Duration timeout = const Duration(seconds: 10),
    bool includeWifi = true,
    bool includeBluetooth = true,
    void Function({String? phase, String? target, String? message})? onWarning,
  }) async* {
    await _ensureInitialized();

    // Pure streaming approach - collect devices as they're discovered
    final List<ZebraDevice> discoveredDevices = [];
    final Set<String> uniqueAddresses = {};
    
    // Start discovery
    _isScanning = true;
    _statusStreamController?.add('Scanning for printers...');

    // Stream controller for device events
    final StreamController<ZebraDevice> deviceController =
        StreamController<ZebraDevice>();

    // Start streaming discovery
    (() async {
      try {
        await _startStreamingDiscovery(
            timeout, uniqueAddresses, deviceController,
            onWarning: onWarning);
      } catch (e) {
        _logger.warning('Failed to start streaming discovery: $e');
      } finally {
        deviceController.close();
      }
    })();

    // Set up timeout
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer(timeout, () {
      _stopAllDiscovery();
      _isScanning = false;
      _statusStreamController?.add('Discovery timeout reached');
      if (!deviceController.isClosed) {
        deviceController.close();
      }
    });

    // Listen to discovered devices and emit filtered lists
    await for (final device in deviceController.stream) {
      // Add to local list if not already present
      if (uniqueAddresses.add(device.address)) {
        // Register device for connection status updates
        ZebraPrinter.registerDevice(device);
        discoveredDevices.add(device);
        
        // Filter devices based on type preferences
        final filteredDevices = discoveredDevices.where((printer) {
          if (!includeWifi && printer.isWifi) return false;
          if (!includeBluetooth && !printer.isWifi) return false;
          return true;
        }).toList();
        
        // Emit the current filtered list
        yield filteredDevices;
        _logger.info('Found printer: ${device.name} (${device.address})');
      }
    }

    // Final cleanup
    if (_isScanning) {
      _stopAllDiscovery();
      _isScanning = false;
    }
  }

  /// Stop printer discovery
  Future<void> stopDiscovery() async {
    await _ensureInitialized();
    _discoveryTimer?.cancel();
    _printer.stopDiscovery();
    _isScanning = false;
    _statusStreamController?.add('Discovery stopped');
  }

  /// Ensure the discovery service is initialized
  Future<void> _ensureInitialized() async {
    if (_devicesStreamController == null) {
      await initialize();
    }
  }

  /// Perform streaming discovery that processes devices as they are found
  Future<void> _performStreamingDiscovery({
    required DateTime endTime,
    required Stream<ZebraDevice> Function() discoveryStreamFunction,
    required void Function(ZebraDevice) onDeviceFound,
    required String phaseName,
    void Function({String? phase, String? target, String? message})? onWarning,
  }) async {
    final Set<String> discoveredAddresses = {};
    StreamSubscription<ZebraDevice>? subscription;

    try {
      _logger.info('$phaseName: Starting streaming discovery');
      // Subscribe to the discovery stream
      subscription = discoveryStreamFunction().listen(
        (device) {
          _logger.info(
              '$phaseName: Received device from stream: ${device.name} (${device.address})');
          // Process device as soon as it's discovered
          if (discoveredAddresses.add(device.address)) {
            onDeviceFound(device);
            _logger.info(
                '$phaseName: Found device ${device.name} (${device.address})');
          }
        },
        onError: (error) {
          _logger.warning('$phaseName stream error: $error');
          onWarning?.call(phase: phaseName, target: null, message: '$error');
        },
        onDone: () {
          _logger.info('$phaseName stream completed');
        },
      );

      // Wait until timeout or cancellation
      while (DateTime.now().isBefore(endTime) && _isScanning) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      _logger.warning('$phaseName discovery error: $e');
      onWarning?.call(phase: phaseName, target: null, message: '$e');
    } finally {
      // Cleanup
      await subscription?.cancel();
      _logger.info('$phaseName discovery completed');
    }
  }

  /// Helper method to calculate remaining timeout value
  int _calculateRemainingTimeout(DateTime endTime) {
    final remainingTime = endTime.difference(DateTime.now()).inMilliseconds;
    _logger.debug(
        'Calculating remaining timeout: ${remainingTime}ms (endTime: $endTime, now: ${DateTime.now()})');
    return remainingTime > 0 ? remainingTime : 1000; // Minimum 1 second
  }

  /// Discover Bluetooth printers with streaming callback
  Future<void> _discoverBluetoothPrintersStream(
      DateTime endTime,
    void Function(ZebraDevice) onPrinterFound,
      {void Function({String? phase, String? target, String? message})?
          onWarning}
  ) async {
    try {
      _isScanning = true;
      
      // Use streaming discovery for BT Classic
      _logger.info(
          'btClassic: About to call discoverBTClassicStream with timeout ${_calculateRemainingTimeout(endTime)}ms');
      await _performStreamingDiscovery(
        endTime: endTime,
        discoveryStreamFunction: () => _printer.discoverBTClassicStream(
          timeout: _calculateRemainingTimeout(endTime),
          onWarning: onWarning,
        ),
        onDeviceFound: onPrinterFound,
        phaseName: 'btClassic',
        onWarning: onWarning,
      );
    } catch (e) {
      _logger.warning('Bluetooth discovery stream failed: $e');
    }
  }

  /// Discover network printers with streaming callback
  /// Uses multiple discovery methods internally for best coverage:
  /// - Local broadcast for same subnet
  /// - Subnet search for common ranges (including iPad hotspot support)
  /// - Directed broadcast for specific network segments
  /// - Multicast for cross-subnet discovery
  Future<void> _discoverNetworkPrintersStream(
      DateTime endTime,
    void Function(ZebraDevice) onPrinterFound,
      {void Function({String? phase, String? target, String? message})?
          onWarning}
  ) async {
    try {
      // Run all network discovery methods concurrently with streaming
      final futures = <Future<void>>[];

      // Local broadcast streaming
      _logger.info(
          'localBroadcast: About to call discoverLocalBroadcastStream with timeout ${_calculateRemainingTimeout(endTime)}ms');
      futures.add(_performStreamingDiscovery(
        endTime: endTime,
        discoveryStreamFunction: () => _printer.discoverLocalBroadcastStream(
          timeout: _calculateRemainingTimeout(endTime),
          onWarning: onWarning,
        ),
        onDeviceFound: onPrinterFound,
        phaseName: 'localBroadcast',
        onWarning: onWarning,
      ));
      
      // Subnet search streaming - covers common network ranges
      futures.add(_performStreamingDiscovery(
        endTime: endTime,
        discoveryStreamFunction: () => _printer.discoverSubnetStream(
          subnet: '192.168.1',
          timeout: _calculateRemainingTimeout(endTime),
          onWarning: onWarning,
        ),
        onDeviceFound: onPrinterFound,
        phaseName: 'subnet',
        onWarning: onWarning,
      ));
      
      // Directed broadcast streaming - targets specific network segments
      futures.add(_performStreamingDiscovery(
        endTime: endTime,
        discoveryStreamFunction: () => _printer.discoverDirectedBroadcastStream(
          ipAddress: '192.168.1.255',
          timeout: _calculateRemainingTimeout(endTime),
          onWarning: onWarning,
        ),
        onDeviceFound: onPrinterFound,
        phaseName: 'directedBroadcast',
        onWarning: onWarning,
      ));

      // Multicast streaming - enables cross-subnet discovery
      futures.add(_performStreamingDiscovery(
        endTime: endTime,
        discoveryStreamFunction: () => _printer.discoverMulticastStream(
          hops: 5,
          timeout: _calculateRemainingTimeout(endTime),
          onWarning: onWarning,
        ),
        onDeviceFound: onPrinterFound,
        phaseName: 'multicast',
        onWarning: onWarning,
      ));

      // Wait for all network discovery methods
      await Future.wait(futures);
    } catch (e) {
      _logger.warning('Network discovery stream failed: $e');
    }
  }

  /// Start streaming discovery with real-time results
  /// Devices are emitted to the stream controller as they are found
  Future<void> _startStreamingDiscovery(
    Duration timeout,
    Set<String> uniqueAddresses,
      StreamController<ZebraDevice> deviceController,
      {void Function({String? phase, String? target, String? message})?
          onWarning}
  ) async {
    // Calculate a single end time for all discovery methods
    final endTime = DateTime.now().add(timeout);
    final completer = Completer<void>();
    int completedMethods = 0;
    const int totalMethods = 2; // Bluetooth + Network

    void checkCompletion() {
      completedMethods++;
      if (completedMethods >= totalMethods && !completer.isCompleted) {
        completer.complete();
      }
    }

    void addPrinter(ZebraDevice printer) {
      if (!deviceController.isClosed) {
        deviceController.add(printer);
      }
    }

    // Start Bluetooth discovery with real-time callback
    _statusStreamController?.add('Starting Bluetooth discovery...');
    _discoverBluetoothPrintersStream(endTime, addPrinter, onWarning: onWarning)
        .then((_) {
      checkCompletion();
    }).catchError((e) {
      _logger.warning('Bluetooth discovery failed: $e');
      checkCompletion();
    });

    // Start enhanced network discovery with real-time callback
    _statusStreamController?.add('Starting enhanced network discovery...');
    _discoverNetworkPrintersStream(endTime, addPrinter, onWarning: onWarning)
        .then((_) {
      checkCompletion();
    }).catchError((e) {
      _logger.warning('Network discovery failed: $e');
      checkCompletion();
    });

    // Wait for all discovery methods to complete or timeout
    await Future.any([
      completer.future,
      Future.delayed(timeout),
    ]);
  }

  /// Stop all discovery operations
  void _stopAllDiscovery() {
    if (_isScanning) {
      _printer.stopDiscovery();
      _isScanning = false;
    }
  }

  /// Dispose of resources
  void dispose() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    // _printer is managed externally and should not be disposed here
    _devicesStreamController?.close();
    _devicesStreamController = null;
    _statusStreamController?.close();
    _statusStreamController = null;
    // Pure streaming service - no collections to clean up
  }
} 