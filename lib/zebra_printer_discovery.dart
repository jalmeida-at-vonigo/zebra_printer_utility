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
  ZebraController? _controller;
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

  /// List of discovered printers
  List<ZebraDevice> get discoveredPrinters => _controller?.printers ?? [];

  /// Initialize the discovery service
  Future<void> initialize({
    ZebraController? controller,
    Function(String)? statusCallback,
  }) async {
    if (_controller != null) return;

    _logger.info('Initializing ZebraPrinterDiscovery service');
    _controller = controller ?? ZebraController();
    _devicesStreamController = StreamController<List<ZebraDevice>>.broadcast();
    _statusStreamController = StreamController<String>.broadcast();

    // Listen to controller changes
    _controller!.addListener(_onControllerChanged);

    // Communication policy is now managed by ZebraPrinterManager
    // This class primarily manages the discovery flow

    // Forward status messages if callback provided
    if (statusCallback != null) {
      _statusStreamController?.stream.listen(statusCallback);
    }
    _logger.info('ZebraPrinterDiscovery initialization completed');
  }

  void _onControllerChanged() {
    _devicesStreamController?.add(_controller!.printers);
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

    // Start discovery
    _isScanning = true;
    // Discovery will be started by individual methods
    _statusStreamController?.add('Scanning for printers...');

    // Kick off discovery concurrently so the stream can yield while discovery runs
    final Set<String> uniqueAddresses = {};
    (() async {
      try {
        await _startStreamingDiscovery(timeout, uniqueAddresses,
            onWarning: onWarning);
      } catch (e) {
        _logger.warning('Failed to start streaming discovery: $e');
      }
    })();

    // Set up timeout
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer(timeout, () {
      _stopAllDiscovery();
      _isScanning = false;
      _statusStreamController?.add('Discovery timeout reached');
    });

    // Track initial count to detect new printers
    final int initialCount = _controller!.printers.length;
    int lastYieldedCount = initialCount;

    // Create a completer to handle the stream completion
    final completer = Completer<void>();
    
    // Listen to controller changes
    void onControllerChanged() {
      final currentPrinters = _controller!.printers;
      final currentCount = currentPrinters.length;

      // Only yield if we have new printers
      if (currentCount > lastYieldedCount) {
        // Mark that we've seen changes
        if (!completer.isCompleted) {
          completer.complete();
        }
        lastYieldedCount = currentCount;
      }
    }

    // Add the listener
    _controller!.addListener(onControllerChanged);

    // Yield initial state if we already have printers
    if (initialCount > 0) {
      final List<ZebraDevice> initialPrinters =
          _controller!.printers.where((printer) {
        if (!includeWifi && printer.isWifi) return false;
        if (!includeBluetooth && !printer.isWifi) return false;
        return true;
      }).toList();

      if (initialPrinters.isNotEmpty) {
        yield initialPrinters;
      }
    }

    // Wait for the first controller change or timeout
    try {
      await completer.future.timeout(timeout);
    } catch (e) {
      // Timeout occurred, continue to yield current state
    }

    // Yield current state
    final List<ZebraDevice> currentPrinters =
        _controller!.printers.where((printer) {
      if (!includeWifi && printer.isWifi) return false;
      if (!includeBluetooth && !printer.isWifi) return false;
      return true;
    }).toList();

    if (currentPrinters.isNotEmpty) {
      yield currentPrinters;
    }

    // Clean up
    _controller!.removeListener(onControllerChanged);
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
    if (_controller == null) {
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
  /// Printers are added to the UI as soon as they are found
  Future<void> _startStreamingDiscovery(
    Duration timeout,
    Set<String> uniqueAddresses,
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
      if (uniqueAddresses.add(printer.address)) {
        _controller!.addPrinter(printer);
        // Immediately notify UI of new printer
        _devicesStreamController?.add(_controller!.printers);
        _logger.info('Found printer: ${printer.name} (${printer.address})');
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

    // Note: per-operation log warnings are emitted via the operation manager.
    // ZebraPrinterDiscovery already exposes status messages; callers can choose to listen
    // to status stream for high-level messages. Detailed per-address/range warnings are
    // available by subscribing directly to ZebraPrinter.operationEvents if needed.
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
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _controller = null;
    _devicesStreamController?.close();
    _devicesStreamController = null;
    _statusStreamController?.close();
    _statusStreamController = null;
    // CommunicationPolicy is no longer managed here,
    // as it's now handled by ZebraPrinterManager.
  }
} 