import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Direct MethodChannel wrapper for Zebra printer operations
/// Encapsulates all native library calls for clarity and debugging
/// 
/// NATIVE CALLS WORKFLOW:
///
/// This implementation mirrors the working Zebra.print() flow by making direct
/// MethodChannel calls to the native iOS/Android ZSDK. The workflow ensures
/// proper CPCL data transmission and printer communication:
///
/// 1. INSTANCE CREATION:
///    - Main channel 'zebrautil' creates printer instance via 'getInstance'
///    - Returns instance ID for dedicated instance channel
///    - Instance channel format: 'ZebraPrinterObject{instanceId}'
///
/// 2. DISCOVERY PHASE:
///    - Instance channel 'startScan' triggers native ZSDK discovery
///    - Native sends 'printerFound' events with device details
///    - Discovery continues until 'onDiscoveryDone' event
///
/// 3. CONNECTION PHASE:
///    - Instance channel 'connectToPrinter' with address parameter
///    - Native ZSDK establishes TCP/Bluetooth connection
///    - Returns boolean success/failure status
///
/// 4. PRINTING PHASE (Critical for CPCL success):
///    - Data preparation: Convert \n to \r\n, add PRINT if missing, add \r\n\r\n
///    - Instance channel 'print' sends prepared data to native ZSDK
///    - Native ZSDK writes data to printer connection
///    - Instance channel 'sendDataWithResponse' sends ETX (\x0C) for CPCL flush
///    - Native adds 100ms delay after flush command
///    - Calculated delay based on data size (2500ms + size multiplier)
///
/// 5. NATIVE ZSDK INTEGRATION:
///    - iOS: Uses ZSDK_API.xcframework via Objective-C wrapper
///    - Android: Uses ZSDK_ANDROID_API.jar
///    - Both platforms handle connection management and data transmission
///    - Native side ensures proper CPCL buffer flushing and timing
///
/// This direct approach bypasses the high-level Zebra service layer while
/// maintaining the exact same native call sequence and parameters that
/// make the Zebra.print() method successful.
class DirectPrinterChannel {
  final String? instanceId;
  final MethodChannel? _instanceChannel;
  final Future<dynamic> Function(MethodCall) _methodCallHandler;

  DirectPrinterChannel({
    required this.instanceId,
    required Future<dynamic> Function(MethodCall) methodCallHandler,
  }) : _instanceChannel = instanceId != null 
           ? MethodChannel('ZebraPrinterObject$instanceId')
           : null,
       _methodCallHandler = methodCallHandler {
    _setupMethodCallHandler();
  }

  void _setupMethodCallHandler() {
    _instanceChannel?.setMethodCallHandler(_methodCallHandler);
  }

  /// Get a new printer instance from the main channel
  static Future<DirectPrinterChannel?> createInstance(
    Future<dynamic> Function(MethodCall) methodCallHandler,
  ) async {
    try {
      const channel = MethodChannel('zebrautil');
      final instanceId = await channel.invokeMethod<String>('getInstance');
      if (instanceId != null) {
        return DirectPrinterChannel(
          instanceId: instanceId,
          methodCallHandler: methodCallHandler,
        );
      }
      return null;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Failed to get instance: $e');
      return null;
    }
  }

  /// Start printer discovery
  Future<bool> startDiscovery() async {
    if (_instanceChannel == null) {
      debugPrint('DirectPrinterChannel: No instance channel available');
      return false;
    }

    try {
      debugPrint('DirectPrinterChannel: Starting discovery');
      await _instanceChannel.invokeMethod('startScan');
      return true;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Discovery error: $e');
      return false;
    }
  }

  /// Stop printer discovery
  Future<bool> stopDiscovery() async {
    if (_instanceChannel == null) return false;

    try {
      debugPrint('DirectPrinterChannel: Stopping discovery');
      await _instanceChannel.invokeMethod('stopScan');
      return true;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Stop discovery error: $e');
      return false;
    }
  }

  /// Connect to a printer by address
  Future<bool> connectToPrinter(String address) async {
    if (_instanceChannel == null) {
      debugPrint('DirectPrinterChannel: No instance channel available');
      return false;
    }

    try {
      debugPrint('DirectPrinterChannel: Connecting to $address');
      final result = await _instanceChannel.invokeMethod<bool>(
        'connectToPrinter',
        {'Address': address},
      );
      debugPrint('DirectPrinterChannel: Connect result: $result');
      return result == true;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Connection error: $e');
      return false;
    }
  }

  /// Disconnect from the current printer
  Future<bool> disconnect() async {
    if (_instanceChannel == null) return false;

    try {
      debugPrint('DirectPrinterChannel: Disconnecting');
      await _instanceChannel.invokeMethod('disconnect');
      return true;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Disconnect error: $e');
      return false;
    }
  }

  /// Print data to the connected printer
  Future<bool> print(String data) async {
    if (_instanceChannel == null) {
      debugPrint('DirectPrinterChannel: No instance channel available');
      return false;
    }

    try {
      debugPrint('DirectPrinterChannel: Printing data (${data.length} chars)');
      final result = await _instanceChannel.invokeMethod<bool>(
        'print',
        {'Data': data},
      );
      debugPrint('DirectPrinterChannel: Print result: $result');
      return result == true;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Print error: $e');
      return false;
    }
  }

  /// Send data with response (for control commands)
  Future<bool> sendDataWithResponse(String data, {int timeout = 1000}) async {
    if (_instanceChannel == null) {
      debugPrint('DirectPrinterChannel: No instance channel available');
      return false;
    }

    try {
      debugPrint('DirectPrinterChannel: Sending data with response: ${data.codeUnits}');
      await _instanceChannel.invokeMethod('sendDataWithResponse', {
        'data': data,
        'timeout': timeout
      });
      return true;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Send data error: $e');
      return false;
    }
  }

  /// Check if printer is connected
  Future<bool> isPrinterConnected() async {
    if (_instanceChannel == null) return false;

    try {
      final result = await _instanceChannel.invokeMethod<bool>('isPrinterConnected');
      return result == true;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Connection check error: $e');
      return false;
    }
  }

  /// Get detailed printer status
  Future<Map<String, dynamic>?> getDetailedPrinterStatus() async {
    if (_instanceChannel == null) return null;

    try {
      final result = await _instanceChannel.invokeMethod('getDetailedPrinterStatus');
      return result is Map<String, dynamic> ? result : null;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Status check error: $e');
      return null;
    }
  }

  /// Set printer settings
  Future<bool> setSettings(String settingCommand) async {
    if (_instanceChannel == null) return false;

    try {
      debugPrint('DirectPrinterChannel: Setting: $settingCommand');
      await _instanceChannel.invokeMethod('setSettings', {
        'SettingCommand': settingCommand
      });
      return true;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Settings error: $e');
      return false;
    }
  }

  /// Get printer setting
  Future<String?> getSetting(String setting) async {
    if (_instanceChannel == null) return null;

    try {
      final result = await _instanceChannel.invokeMethod<String>('getSetting', {
        'setting': setting
      });
      return result;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Get setting error: $e');
      return null;
    }
  }

  /// Check if the channel is ready
  bool get isReady => _instanceChannel != null;

  /// Get the instance ID
  String? get getInstanceId => instanceId;
}

// Simple device model for direct MethodChannel usage
class DirectDevice {
  final String address;
  final String name;
  final String status;
  final bool isWifi;
  final bool isBluetooth;
  final String? brand;
  final String? model;
  final String? displayName;
  final String? manufacturer;
  final String? firmwareRevision;
  final String? hardwareRevision;
  final String? connectionType;

  DirectDevice({
    required this.address,
    required this.name,
    required this.status,
    required this.isWifi,
    this.isBluetooth = false,
    this.brand,
    this.model,
    this.displayName,
    this.manufacturer,
    this.firmwareRevision,
    this.hardwareRevision,
    this.connectionType,
  });

  factory DirectDevice.fromMap(Map<dynamic, dynamic> map) {
    return DirectDevice(
      address: map['address'] ?? map['Address'] ?? '',
      name: map['name'] ?? map['Name'] ?? 'Unknown Printer',
      status: map['status'] ?? map['Status'] ?? 'Found',
      isWifi: map['isWifi'] == true || map['IsWifi'] == true || map['isWifi'] == 'true' || map['IsWifi'] == 'true',
      isBluetooth: map['isBluetooth'] == true || map['IsBluetooth'] == true || map['isBluetooth'] == 'true' || map['IsBluetooth'] == 'true',
      brand: map['brand'] ?? map['Brand'],
      model: map['model'] ?? map['Model'],
      displayName: map['displayName'] ?? map['DisplayName'],
      manufacturer: map['manufacturer'] ?? map['Manufacturer'],
      firmwareRevision: map['firmwareRevision'] ?? map['FirmwareRevision'],
      hardwareRevision: map['hardwareRevision'] ?? map['HardwareRevision'],
      connectionType: map['connectionType'] ?? map['ConnectionType'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DirectDevice && other.address == address;
  }

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() => 'DirectDevice($address, $name)';
}

class DirectPrintScreen extends StatefulWidget {
  const DirectPrintScreen({super.key});

  @override
  State<DirectPrintScreen> createState() => _DirectPrintScreenState();
}

class _DirectPrintScreenState extends State<DirectPrintScreen>
    with SingleTickerProviderStateMixin {
  DirectDevice? _selectedDevice;
  bool _isConnected = false;
  String _status = 'Not connected';
  bool _isPrinting = false;
  late TextEditingController _cpclController;
  bool _useSimpleExample = false;

  // Device discovery state
  final List<DirectDevice> _discoveredDevices = [];
  bool _isDiscovering = false;
  bool _isConnecting = false;
  String? _connectingAddress;
  final Set<String> _discoveredAddresses = {};

  // Manual entry state
  bool _manualEntryMode = false;
  final _manualIpController = TextEditingController();
  final _manualNameController = TextEditingController();
  String? _manualError;

  // Direct printer channel
  DirectPrinterChannel? _printerChannel;

  // Tab controller for better organization
  late TabController _tabController;

  final String defaultCPCL = """! 0 200 200 400 1
ON-FEED IGNORE
LABEL
CONTRAST 0
TONE 0
SPEED 5
PAGE-WIDTH 800
BAR-SENSE
PCX 11 8 !<PRISMLOGO.png
T 7 1 550 91 Bedroom 2 test value
T 7 1 220 190 Equalizer
T 7 1 550 42 6/27/2025
T 7 1 220 42 Test Jane
T 4 0 220 91 104
CENTER 800
BT 0 4 8
B 39 1 1 50 0 237 00170000010422
BT OFF
LEFT 0
T 4 0 88 169 689
FORM
PRINT
""";

  final String simpleCPCL = """! 0 200 200 210 1
TEXT 4 0 30 40 Hello from Flutter!
TEXT 4 0 30 100 Test Label
TEXT 4 0 30 160 CPCL Mode
FORM
PRINT
""";

  final String compactCPCL = """! 0 200 200 100 1
TEXT 4 0 10 10 Test Print
TEXT 4 0 10 40 ${DateTime.now().toString().substring(0, 16)}
FORM
PRINT
""";

  @override
  void initState() {
    super.initState();
    _cpclController = TextEditingController(text: simpleCPCL);
    _tabController = TabController(length: 3, vsync: this);
    _initPrinterState();
  }

  Future<void> _initPrinterState() async {
    try {
      // Get instance ID from main channel
      _printerChannel = await DirectPrinterChannel.createInstance(_handleMethodCall);
      
      if (_printerChannel != null) {
        setState(() => _status = 'Ready - Instance: ${_printerChannel!.getInstanceId}');
      } else {
        setState(() => _status = 'Failed to initialize printer channel.');
      }
    } catch (e) {
      debugPrint('Direct Print Screen: Initialization error: $e');
      setState(() => _status = 'Init Error: $e');
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'printerFound':
        _handlePrinterFound(call.arguments);
        break;
      case 'onDiscoveryError':
        _handleDiscoveryError(call.arguments);
        break;
      case 'onDiscoveryDone':
        _handleDiscoveryDone(call.arguments);
        break;
      case 'changePrinterStatus':
        _handleStatusChange(call.arguments);
        break;
      case 'printerRemoved':
        _handlePrinterRemoved(call.arguments);
        break;
    }
  }

  void _handlePrinterFound(dynamic arguments) {
    if (arguments is Map<dynamic, dynamic>) {
      final device = DirectDevice.fromMap(arguments);
      debugPrint('Direct Print Screen: Printer found: ${device.name} at ${device.address}');
      
      if (mounted && !_discoveredAddresses.contains(device.address)) {
        setState(() {
          _discoveredAddresses.add(device.address);
          _discoveredDevices.add(device);
        });
      }
    }
  }

  void _handleDiscoveryError(dynamic arguments) {
    debugPrint('Direct Print Screen: Discovery error: $arguments');
    if (mounted) {
      setState(() {
        _status = 'Discovery error: $arguments';
        _isDiscovering = false;
      });
    }
  }

  void _handleDiscoveryDone(dynamic arguments) {
    debugPrint('Direct Print Screen: Discovery done');
    if (mounted) {
      setState(() {
        _isDiscovering = false;
        if (_discoveredDevices.isEmpty) {
          _status = 'No printers found';
        } else {
          _status = 'Found ${_discoveredDevices.length} printer(s)';
        }
      });
    }
  }

  void _handleStatusChange(dynamic arguments) {
    if (arguments is Map<String, dynamic>) {
      final status = arguments['Status'] ?? '';
      final color = arguments['Color'] ?? 'R';
      debugPrint('Direct Print Screen: Status change: $status, color: $color');
      if (mounted) {
        setState(() => _status = status);
      }
    }
  }

  void _handlePrinterRemoved(dynamic arguments) {
    if (arguments is Map<String, dynamic>) {
      final address = arguments['Address'] ?? '';
      debugPrint('Direct Print Screen: Printer removed: $address');
      if (mounted && _selectedDevice?.address == address) {
        setState(() {
          _selectedDevice = null;
          _isConnected = false;
          _status = 'Printer disconnected';
        });
      }
    }
  }

  Future<void> _startDiscovery() async {
    if (_printerChannel == null) {
      debugPrint('Direct Print Screen: No printer channel available');
      return;
    }

    setState(() {
      _isDiscovering = true;
      _discoveredDevices.clear();
      _discoveredAddresses.clear();
      _status = 'Discovering printers...';
    });

    try {
      debugPrint('Direct Print Screen: Starting discovery');
      
      // Start discovery using DirectPrinterChannel
      await _printerChannel!.startDiscovery();
      
    } catch (e) {
      debugPrint('Direct Print Screen: Discovery error: $e');
      setState(() {
        _isDiscovering = false;
        _status = 'Discovery error: $e';
      });
    }
  }

  Future<void> _stopDiscovery() async {
    if (_printerChannel == null) return;

    try {
      await _printerChannel!.stopDiscovery();
      setState(() {
        _isDiscovering = false;
      });
    } catch (e) {
      debugPrint('Direct Print Screen: Stop discovery error: $e');
    }
  }

  Future<void> _connectToDevice(DirectDevice device) async {
    if (_printerChannel == null) {
      debugPrint('Direct Print Screen: No printer channel available');
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectingAddress = device.address;
      _status = 'Connecting to ${device.name}...';
    });

    try {
      debugPrint('Direct Print Screen: Connecting to ${device.address}');
      
      // Connect to printer using DirectPrinterChannel
      final connectResult = await _printerChannel!.connectToPrinter(device.address);

      debugPrint('Direct Print Screen: Connect result: $connectResult');

      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectingAddress = null;
          _isConnected = connectResult == true;
          _selectedDevice = device;
          _status = connectResult == true
              ? 'Connected to ${device.name}'
              : 'Failed to connect to ${device.name}';
        });
      }
    } catch (e) {
      debugPrint('Direct Print Screen: Connection error: $e');
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectingAddress = null;
          _isConnected = false;
          _status = 'Connection error: $e';
        });
      }
    }
  }

  Future<void> _disconnect() async {
    if (_printerChannel == null) return;

    setState(() {
      _status = 'Disconnecting...';
    });

    try {
      await _printerChannel!.disconnect();
      if (mounted) {
        setState(() {
          _isConnected = false;
          _selectedDevice = null;
          _status = 'Disconnected';
        });
      }
    } catch (e) {
      debugPrint('Direct Print Screen: Disconnect error: $e');
      if (mounted) {
        setState(() {
          _status = 'Disconnect error: $e';
        });
      }
    }
  }

  Future<void> _connectManual() async {
    final ip = _manualIpController.text.trim();
    if (ip.isEmpty || !_validateIp(ip)) {
      setState(() => _manualError = 'Enter a valid IP address');
      return;
    }

    setState(() {
      _manualError = null;
      _isConnecting = true;
      _connectingAddress = ip;
      _status = 'Connecting to $ip...';
    });

    try {
      final device = DirectDevice(
        address: ip,
        name: _manualNameController.text.trim().isNotEmpty
            ? _manualNameController.text.trim()
            : 'Custom Printer ($ip)',
        status: 'Manual',
        isWifi: true,
        brand: 'Zebra',
        connectionType: 'manual',
      );

      await _connectToDevice(device);
    } catch (e) {
      debugPrint('Direct Print Screen: Manual connection error: $e');
      setState(() {
        _isConnecting = false;
        _connectingAddress = null;
        _status = 'Manual connection error: $e';
      });
    }
  }

  bool _validateIp(String ip) {
    final regex = RegExp(r'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$');
    if (!regex.hasMatch(ip)) return false;
    return ip.split('.').every((octet) {
      final n = int.tryParse(octet);
      return n != null && n >= 0 && n <= 255;
    });
  }

  @override
  void dispose() {
    _cpclController.dispose();
    _manualIpController.dispose();
    _manualNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Executes the complete native printing workflow for CPCL data.
  ///
  /// NATIVE CALL SEQUENCE:
  /// 1. Data preparation (Dart side) - mirrors Zebra.print() preprocessing
  /// 2. _printerChannel!.print(preparedData) - sends data to native ZSDK
  /// 3. _printerChannel!.sendDataWithResponse('\x0C') - CPCL buffer flush
  /// 4. Delays and timing - ensures complete transmission
  ///
  /// This method replicates the exact native call sequence from the working
  /// Zebra.print(data, format: PrintFormat.cpcl) implementation.
  Future<void> _print() async {
    if (!_isConnected || _selectedDevice == null || _printerChannel == null) {
      debugPrint('Direct Print Screen: Cannot print - not connected or no printer channel');
      return;
    }

    if (mounted) {
      setState(() => _isPrinting = true);
    }

    try {
      debugPrint('Direct Print Screen: Starting print operation');
      
      // Follow the exact same data preparation as the working implementation
      String preparedData = _cpclController.text;
      
      // 1. For CPCL, ensure proper line endings - convert any \n to \r\n for CPCL
      preparedData = preparedData.replaceAll(RegExp(r'(?<!\r)\n'), '\r\n');

      // 2. Check if CPCL data ends with FORM but missing PRINT
      if (preparedData.trim().endsWith('FORM') &&
          !preparedData.contains('PRINT')) {
        debugPrint(
            'Direct Print Screen: CPCL data missing PRINT command, adding it');
        preparedData = '${preparedData.trim()}\r\nPRINT\r\n';
      }

      // 3. Ensure CPCL ends with proper line endings for buffer flush
      if (!preparedData.endsWith('\r\n')) {
        preparedData += '\r\n';
      }

      // 4. Add extra line feeds to ensure complete transmission
      // This helps flush the buffer without using control characters
      preparedData += '\r\n\r\n';

      debugPrint(
          'Direct Print Screen: Sending CPCL data (${preparedData.length} chars)');

      // 5. Send the main data using DirectPrinterChannel
      final printResult = await _printerChannel!.print(preparedData);

      debugPrint('Direct Print Screen: Print result: $printResult');

      if (printResult == true) {
        debugPrint('Direct Print Screen: Print data sent successfully');
        
        // 6. For CPCL, send ETX as a command (not print data) to ensure proper termination
        debugPrint('Direct Print Screen: Sending CPCL termination command');
        await _printerChannel!.sendDataWithResponse('\x0C', timeout: 1000);
        await Future.delayed(const Duration(milliseconds: 100));
        debugPrint('Direct Print Screen: CPCL buffer flushed');

        // 7. Calculate delay based on data size (same as working implementation)
        final dataLength = preparedData.length;
        const baseDelay = 2500; // CPCL base delay
        final sizeMultiplier = (dataLength / 1000).ceil(); // Extra 1s per KB
        final effectiveDelay =
            Duration(milliseconds: baseDelay + (sizeMultiplier * 1000));

        debugPrint(
            'Direct Print Screen: Waiting ${effectiveDelay.inMilliseconds}ms for print completion (data size: $dataLength bytes)');
        await Future.delayed(effectiveDelay);

        debugPrint(
            'Direct Print Screen: Print operation completed successfully');
      }

      if (mounted) {
        setState(() {
          _isPrinting = false;
          if (printResult != true) {
            _status = 'Print failed';
          } else {
            _status = 'Print successful';
          }
        });
      }
    } catch (e) {
      debugPrint('Direct Print Screen: Print error: $e');
      if (mounted) {
        setState(() {
          _isPrinting = false;
          _status = 'Print error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Direct Print - MethodChannel'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.print), text: 'Print'),
            Tab(icon: Icon(Icons.search), text: 'Connect'),
            Tab(icon: Icon(Icons.info), text: 'Status'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrintTab(),
          _buildConnectTab(),
          _buildStatusTab(),
        ],
      ),
    );
  }

  Widget _buildPrintTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection status banner
          if (!_isConnected)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Not connected to printer. Go to Connect tab to find and connect to a printer.',
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // CPCL Editor Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CPCL Commands',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _useSimpleExample = !_useSimpleExample;
                              _cpclController.text =
                                  _useSimpleExample ? simpleCPCL : defaultCPCL;
                            });
                          },
                          icon: const Icon(Icons.swap_horiz),
                          label: Text(_useSimpleExample ? 'Complex' : 'Simple'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _cpclController.text = compactCPCL;
                            });
                          },
                          icon: const Icon(Icons.schedule),
                          label: const Text('Quick'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: _cpclController,
                    maxLines: null,
                    expands: true,
                    contextMenuBuilder: null,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      hintText: 'Enter CPCL commands here...',
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          
          // Print button
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isConnected && !_isPrinting ? _print : null,
              icon: _isPrinting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.print, size: 24),
              label: Text(
                _isPrinting ? 'Printing...' : 'Print',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isConnected ? Colors.blue : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection mode selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connection Method',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildModeButton(
                          title: 'Auto Discovery',
                          subtitle: 'Find nearby printers',
                          icon: Icons.search,
                          isSelected: !_manualEntryMode,
                          onTap: () => setState(() => _manualEntryMode = false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildModeButton(
                          title: 'Manual Entry',
                          subtitle: 'Enter IP address',
                          icon: Icons.edit,
                          isSelected: _manualEntryMode,
                          onTap: () => setState(() => _manualEntryMode = true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Connection content
          Expanded(
            child: _manualEntryMode
                ? _buildManualEntry()
                : _buildDiscoverySection(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.blue : Colors.grey[800],
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.blue[700] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Discovery controls
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Printer Discovery',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      onPressed:
                          _isDiscovering ? _stopDiscovery : _startDiscovery,
                      icon: _isDiscovering
                          ? const Icon(Icons.stop, size: 18)
                          : const Icon(Icons.search, size: 18),
                      label: Text(_isDiscovering ? 'Stop' : 'Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isDiscovering ? Colors.red : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
                if (_isDiscovering) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    'Searching for printers...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Discovered devices
        Expanded(
          child: _discoveredDevices.isEmpty
              ? _buildEmptyState()
              : _buildDeviceGrid(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isDiscovering ? Icons.search : Icons.print_disabled,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _isDiscovering
                  ? 'Searching for printers...'
                  : 'No printers found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isDiscovering
                  ? 'Make sure your printer is turned on and connected to the network'
                  : 'Start discovery to find available printers',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _discoveredDevices.length,
      itemBuilder: (context, index) {
        final device = _discoveredDevices[index];
        final isSelected = _selectedDevice?.address == device.address;
        final isConnecting = _connectingAddress == device.address;

        return Card(
          elevation: isSelected ? 4 : 1,
          color: isSelected
              ? (_isConnected ? Colors.green[50] : Colors.blue[50])
              : null,
          child: InkWell(
            onTap: () => setState(() => _selectedDevice = device),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        device.isWifi ? Icons.wifi : Icons.bluetooth,
                        color: device.isWifi ? Colors.blue : Colors.blue[700],
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          device.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    device.address,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: ElevatedButton(
                      onPressed: (_isConnected && isSelected) ||
                              isConnecting ||
                              _isConnecting
                          ? null
                          : () => _connectToDevice(device),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected && _isConnected
                            ? Colors.green
                            : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: isConnecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isConnected && isSelected
                              ? 'Connected'
                              : 'Connect'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildManualEntry() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manual Connection',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _manualIpController,
              decoration: InputDecoration(
                labelText: 'Printer IP Address',
                hintText: 'e.g. 192.168.1.100',
                errorText: _manualError,
                prefixIcon: const Icon(Icons.computer),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.url,
              autofillHints: const [AutofillHints.url],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualNameController,
              decoration: InputDecoration(
                labelText: 'Printer Name (optional)',
                hintText: 'e.g. Custom Zebra',
                prefixIcon: const Icon(Icons.label),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isConnecting ? null : _connectManual,
                icon: _connectingAddress == _manualIpController.text.trim()
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.link),
                label: const Text('Connect to Printer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isConnected ? Icons.check_circle : Icons.error,
                        color: _isConnected ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Connection Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isConnected ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _status,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_printerChannel != null &&
                      _printerChannel!.getInstanceId != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Instance ID: ${_printerChannel!.getInstanceId}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Selected device info
          if (_selectedDevice != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selected Printer',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Name', _selectedDevice!.name),
                    _buildInfoRow('Address', _selectedDevice!.address),
                    _buildInfoRow(
                        'Type', _selectedDevice!.isWifi ? 'WiFi' : 'Bluetooth'),
                    if (_selectedDevice!.brand != null)
                      _buildInfoRow('Brand', _selectedDevice!.brand!),
                    if (_selectedDevice!.model != null)
                      _buildInfoRow('Model', _selectedDevice!.model!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Actions
          if (_isConnected) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Actions',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _disconnect,
                        icon: const Icon(Icons.link_off),
                        label: const Text('Disconnect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const Spacer(),

          // Quick actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _startDiscovery,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _tabController.animateTo(0),
                          icon: const Icon(Icons.print),
                          label: const Text('Print'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
} 