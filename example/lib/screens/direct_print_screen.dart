import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zebrautil/internal/logger.dart';
import 'package:zebrautil/models/print_enums.dart';

import '../widgets/print_data_editor.dart' as editor;
import '../widgets/log_panel.dart';
import '../widgets/responsive_layout.dart';

/// Direct MethodChannel wrapper for Zebra printer operations
/// Demonstrates direct native platform calls bypassing the library
class DirectPrinterChannel {
  final String? instanceId;
  final MethodChannel? _instanceChannel;
  final Future<dynamic> Function(MethodCall) _methodCallHandler;
  final Logger _logger = Logger.withPrefix('DirectPrinterChannel');

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
    _logger.debug(
        'Setting up method call handler for channel: ${_instanceChannel?.name}');
    _instanceChannel?.setMethodCallHandler(_methodCallHandler);
    _logger.debug('Method call handler setup complete');
  }

  /// Generate a unique operation ID for native calls
  String _generateOperationId() {
    final operationId =
        'direct_${DateTime.now().millisecondsSinceEpoch}_${instanceId ?? 'unknown'}';
    _logger.debug('Generated operation ID: $operationId');
    return operationId;
  }

  /// Add operationId to arguments if not present
  Map<String, dynamic> _prepareArguments(Map<String, dynamic>? arguments) {
    _logger.debug('Preparing arguments: $arguments');
    final args = Map<String, dynamic>.from(arguments ?? {});
    if (!args.containsKey('operationId')) {
      final operationId = _generateOperationId();
      args['operationId'] = operationId;
      _logger.debug('Added operationId to arguments: $operationId');
    } else {
      _logger.debug(
          'OperationId already present in arguments: ${args['operationId']}');
    }
    _logger.debug('Final arguments: $args');
    return args;
  }

  static Future<DirectPrinterChannel?> createInstance(
    Future<dynamic> Function(MethodCall) methodCallHandler,
  ) async {
    final logger = Logger.withPrefix('DirectPrinterChannel');
    logger.debug('Creating DirectPrinterChannel instance...');
    
    try {
      const channel = MethodChannel('zebrautil');
      logger.debug('Invoking getInstance on main channel...');
      final instanceId = await channel.invokeMethod<String>('getInstance');
      logger.debug('getInstance returned: $instanceId');
      
      if (instanceId != null) {
        logger.debug(
            'Creating DirectPrinterChannel with instanceId: $instanceId');
        final instance = DirectPrinterChannel(
          instanceId: instanceId,
          methodCallHandler: methodCallHandler,
        );
        logger.debug('DirectPrinterChannel instance created successfully');
        return instance;
      } else {
        logger.warning('getInstance returned null');
        return null;
      }
    } catch (e) {
      logger.error('Failed to get instance: $e', e);
      return null;
    }
  }

  // NOTE: This screen demonstrates direct low-level MethodChannel usage
  // For production code, use the high-level API (Zebra.global or ZebraPrinter)
  Future<bool> startDiscovery() async {
    _logger.debug('Starting discovery...');

    if (_instanceChannel == null) {
      _logger.error('Cannot start discovery: instance channel is null');
      return false;
    }
    
    try {
      _logger.debug('Starting all discovery methods concurrently...');
      
      // Start all discovery methods concurrently via direct channel calls
      final futures = [
        _instanceChannel.invokeMethod(
            'discoverBTClassic', _prepareArguments({'timeout': 10000})),
        _instanceChannel.invokeMethod(
            'discoverLocalBroadcast', _prepareArguments({'timeout': 10000})),
        _instanceChannel.invokeMethod('discoverSubnet',
            _prepareArguments({'subnet': '192.168.1', 'timeout': 10000})),
        _instanceChannel.invokeMethod('discoverMulticast',
            _prepareArguments({'hops': 5, 'timeout': 10000})),
      ];

      _logger.debug('Waiting for all discovery methods to complete...');
      await Future.wait(futures);
      _logger.debug('All discovery methods completed successfully');
      return true;
    } catch (e) {
      _logger.error('Discovery error: $e', e);
      return false;
    }
  }

  Future<bool> stopDiscovery() async {
    _logger.debug('Stopping discovery...');

    if (_instanceChannel == null) {
      _logger.error('Cannot stop discovery: instance channel is null');
      return false;
    }
    
    try {
      _logger.debug('Invoking stopScan...');
      await _instanceChannel.invokeMethod('stopScan', _prepareArguments({}));
      _logger.debug('stopScan completed successfully');
      return true;
    } catch (e) {
      _logger.error('Stop discovery error: $e', e);
      return false;
    }
  }

  Future<bool> connectToPrinter(String address) async {
    _logger.debug('Connecting to printer: $address');

    if (_instanceChannel == null) {
      _logger.error('Cannot connect: instance channel is null');
      return false;
    }
    
    try {
      _logger.debug('Invoking connectToPrinter...');
      final result = await _instanceChannel.invokeMethod<bool>(
        'connectToPrinter',
        _prepareArguments({'Address': address}),
      );
      _logger.debug('connectToPrinter returned: $result');
      return result == true;
    } catch (e) {
      _logger.error('Connection error: $e', e);
      return false;
    }
  }

  Future<bool> disconnect() async {
    _logger.debug('Disconnecting from printer...');

    if (_instanceChannel == null) {
      _logger.error('Cannot disconnect: instance channel is null');
      return false;
    }
    
    try {
      _logger.debug('Invoking disconnect...');
      await _instanceChannel.invokeMethod('disconnect', _prepareArguments({}));
      _logger.debug('disconnect completed successfully');
      return true;
    } catch (e) {
      _logger.error('Disconnect error: $e', e);
      return false;
    }
  }

  Future<bool> print(String data) async {
    _logger.debug('Printing data (${data.length} bytes)...');

    if (_instanceChannel == null) {
      _logger.error('Cannot print: instance channel is null');
      return false;
    }
    
    try {
      _logger.debug('Invoking print...');
      final result = await _instanceChannel.invokeMethod<bool>(
        'print',
        _prepareArguments({'Data': data}),
      );
      _logger.debug('print returned: $result');
      return result == true;
    } catch (e) {
      _logger.error('Print error: $e', e);
      return false;
    }
  }

  Future<bool> sendFlushCommand(String data) async {
    _logger.debug('Sending flush command: $data');

    if (_instanceChannel == null) {
      _logger.error('Cannot send flush command: instance channel is null');
      return false;
    }
    
    try {
      _logger.debug('Invoking setSettings for flush command...');
      final result = await _instanceChannel.invokeMethod<bool>(
        'setSettings',
        _prepareArguments({'SettingCommand': data}),
      );
      _logger.debug('setSettings returned: $result');
      return result == true;
    } catch (e) {
      _logger.error('Flush command error: $e', e);
      return false;
    }
  }

  bool get isReady => _instanceChannel != null;
  String? get getInstanceId => instanceId;
}

// Simple device model for direct MethodChannel usage
class DirectDevice {
  final String address;
  final String name;
  final bool isWifi;

  DirectDevice({
    required this.address,
    required this.name,
    required this.isWifi,
  });

  factory DirectDevice.fromMap(Map<dynamic, dynamic> map) {
    return DirectDevice(
      address: map['address'] ?? map['Address'] ?? '',
      name: map['name'] ?? map['Name'] ?? 'Unknown Printer',
      isWifi: map['isWifi'] == true || map['IsWifi'] == true,
    );
  }
}

/// Direct print screen demonstrating low-level MethodChannel usage
class DirectPrintScreen extends StatefulWidget {
  const DirectPrintScreen({super.key});

  @override
  State<DirectPrintScreen> createState() => _DirectPrintScreenState();
}

class _DirectPrintScreenState extends State<DirectPrintScreen> {
  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  final List<LogEntry> _logs = [];
  final List<DirectDevice> _devices = [];
  final Logger _logger = Logger.withPrefix('DirectPrintScreen');
  
  DirectPrinterChannel? _printerChannel;
  DirectDevice? _selectedDevice;
  bool _isPrinterConnected = false;
  bool _isPrinting = false;
  bool _isDiscovering = false;
  PrintFormat _format = PrintFormat.cpcl;

  @override
  void initState() {
    super.initState();
    // Set default CPCL data
    _dataController.text = '''! 0 200 200 210 1
TEXT 4 0 30 40 Direct Channel Test
TEXT 4 0 30 100 Low-level API Demo
TEXT 4 0 30 160 CPCL Mode
FORM
PRINT''';
    _initPrinterChannel();
  }

  @override
  void dispose() {
    _dataController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _initPrinterChannel() async {
    _addLog('Initializing direct printer channel...', 'info');
    
    try {
      _addLog('Creating DirectPrinterChannel instance...', 'debug');
      _printerChannel = await DirectPrinterChannel.createInstance(_handleMethodCall);
      
      if (_printerChannel != null) {
        _addLog('Channel initialized', 'success', 
          details: 'Instance ID: ${_printerChannel!.getInstanceId}');
        _addLog('Channel ready: ${_printerChannel!.isReady}', 'debug');
      } else {
        _addLog('Failed to initialize channel', 'error');
      }
    } catch (e) {
      _addLog('Initialization error', 'error', details: '$e');
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    // Console logging to ensure we see events in debug console
    _logger.info(
        '🔍 DIRECT_SCREEN: Native event received - Method: ${call.method}');
    _logger.info('🔍 DIRECT_SCREEN: Arguments: ${call.arguments}');
    _logger.info(
        '🔍 DIRECT_SCREEN: Arguments type: ${call.arguments.runtimeType}');

    // Comprehensive logging to investigate native layer events
    _addLog('=== NATIVE EVENT RECEIVED ===', 'debug');
    _addLog('Method: ${call.method}', 'debug');
    _addLog('Arguments: ${call.arguments}', 'debug');
    _addLog('Arguments type: ${call.arguments.runtimeType}', 'debug');
    if (call.arguments is Map) {
      _addLog(
          'Arguments keys: ${(call.arguments as Map).keys.toList()}', 'debug');
      if ((call.arguments as Map).containsKey('operationId')) {
        _addLog(
            'OperationId: ${(call.arguments as Map)['operationId']}', 'debug');
      }
    }
    _addLog('=== END NATIVE EVENT ===', 'debug');
    
    switch (call.method) {
      // Discovery events
      case 'printerFound':
      case 'discoverBTClassic_printerFound':
      case 'discoverLocalBroadcast_printerFound':
      case 'discoverSubnet_printerFound':
      case 'discoverDirectedBroadcast_printerFound':
      case 'discoverMulticast_printerFound':
        _logger
            .info('🎯 DIRECT_SCREEN: DISCOVERY EVENT MATCHED: ${call.method}');
        _addLog('DISCOVERY EVENT MATCHED: ${call.method}', 'debug');
        _handlePrinterFound(call.arguments);
        break;
        
      // Discovery completion
      case 'discoverBTClassic_onComplete':
      case 'discoverLocalBroadcast_onComplete':
      case 'discoverSubnet_onComplete':
      case 'discoverDirectedBroadcast_onComplete':
      case 'discoverMulticast_onComplete':
        _logger.info(
            '✅ DIRECT_SCREEN: DISCOVERY COMPLETION MATCHED: ${call.method}');
        _addLog('DISCOVERY COMPLETION MATCHED: ${call.method}', 'debug');
        _handleDiscoveryComplete(call.method, call.arguments);
        break;

      // Discovery errors
      case 'discoverBTClassic_onError':
      case 'discoverLocalBroadcast_onError':
      case 'discoverSubnet_onError':
      case 'discoverDirectedBroadcast_onError':
      case 'discoverMulticast_onError':
        _addLog('DISCOVERY ERROR MATCHED: ${call.method}', 'debug');
        _handleDiscoveryError(call.method, call.arguments);
        break;

      // Stop scan completion
      case 'stopScan_onComplete':
        _handleStopScanComplete(call.arguments);
        break;

      // Connection events
      case 'connectToPrinter_onComplete':
        _handleConnectionComplete(call.arguments);
        break;
      case 'connectToPrinter_onError':
        _handleConnectionError(call.arguments);
        break;
      case 'disconnect_onComplete':
        _handleDisconnectComplete(call.arguments);
        break;
      case 'disconnect_onError':
        _handleDisconnectError(call.arguments);
        break;

      // Print events
      case 'print_onComplete':
        _handlePrintComplete(call.arguments);
        break;
      case 'print_onError':
        _handlePrintError(call.arguments);
        break;
      case 'print_statusUpdate':
        _handlePrintStatusUpdate(call.arguments);
        break;
      case 'print_progressUpdate':
        _handlePrintProgressUpdate(call.arguments);
        break;

      // Settings events
      case 'setSettings_onComplete':
        _handleSettingsComplete(call.arguments);
        break;
      case 'setSettings_onError':
        _handleSettingsError(call.arguments);
        break;

      // Connection status events
      case 'connection_statusChanged':
        _handleConnectionStatusChanged(call.arguments);
        break;
      case 'connection_lost':
        _handleConnectionLost(call.arguments);
        break;

      // Discovery warnings
      case 'discovery_logWarning':
        _handleDiscoveryWarning(call.arguments);
        break;

      // Unknown method
      case 'onMethodNotImplemented':
        _addLog('Method not implemented', 'warning',
            details: '${call.arguments}');
        break;

      default:
        _addLog('UNMATCHED EVENT - Method: ${call.method}', 'warning');
        _addLog('UNMATCHED EVENT - Arguments: ${call.arguments}', 'warning');
        break;
    }
  }

  void _handlePrinterFound(dynamic arguments) {
    _addLog('=== PRINTER FOUND DATA ===', 'debug');
    _addLog('Arguments: $arguments', 'debug');
    _addLog('Arguments type: ${arguments.runtimeType}', 'debug');
    
    if (arguments is Map<dynamic, dynamic>) {
      _addLog('Arguments keys: ${arguments.keys.toList()}', 'debug');
      _addLog(
          'Address: ${arguments['address'] ?? arguments['Address']}', 'debug');
      _addLog('Name: ${arguments['name'] ?? arguments['Name']}', 'debug');
      _addLog('IsWifi: ${arguments['isWifi'] ?? arguments['IsWifi']}', 'debug');
      
      final device = DirectDevice.fromMap(arguments);
      _addLog('Created device: ${device.name} (${device.address})', 'debug');
      
      if (!_devices.any((d) => d.address == device.address)) {
        setState(() {
          _devices.add(device);
        });
        _addLog('Printer found', 'info', 
          details: '${device.name} (${device.address})');
      } else {
        _addLog('Device already in list, skipping', 'debug');
      }
    } else {
      _addLog('Arguments is not a Map, cannot process', 'warning');
    }
    _addLog('=== END PRINTER FOUND DATA ===', 'debug');
  }



  void _handleDiscoveryComplete(String method, dynamic arguments) {
    final discoveryType = method.replaceAll('_onComplete', '');
    _addLog('Discovery completed', 'success',
        details: '$discoveryType completed');

    // Check if all discovery methods are done
    if (_isDiscovering) {
      setState(() {
        _isDiscovering = false;
      });
      _addLog('All discovery methods completed', 'success',
          details: 'Found ${_devices.length} printer(s)');
    }
  }

  void _handleDiscoveryError(String method, dynamic arguments) {
    final discoveryType = method.replaceAll('_onError', '');
    _addLog('Discovery error', 'error',
        details: '$discoveryType failed: $arguments');
  }

  void _handleStopScanComplete(dynamic arguments) {
    _addLog('Stop scan completed', 'success');
    setState(() {
      _isDiscovering = false;
    });
  }

  void _handleConnectionComplete(dynamic arguments) {
    _addLog('Connection completed', 'success',
        details: 'Successfully connected to printer');
    setState(() {
      _isPrinterConnected = true;
    });
  }

  void _handleConnectionError(dynamic arguments) {
    _addLog('Connection failed', 'error',
        details: 'Failed to connect: $arguments');
    setState(() {
      _isPrinterConnected = false;
    });
  }

  void _handleDisconnectComplete(dynamic arguments) {
    _addLog('Disconnect completed', 'success');
    setState(() {
      _isPrinterConnected = false;
      _selectedDevice = null;
    });
  }

  void _handleDisconnectError(dynamic arguments) {
    _addLog('Disconnect error', 'error',
        details: 'Failed to disconnect: $arguments');
  }

  void _handlePrintComplete(dynamic arguments) {
    _addLog('Print completed', 'success',
        details: 'Print job completed successfully');
    setState(() {
      _isPrinting = false;
    });
  }

  void _handlePrintError(dynamic arguments) {
    _addLog('Print failed', 'error', details: 'Print job failed: $arguments');
    setState(() {
      _isPrinting = false;
    });
  }

  void _handlePrintStatusUpdate(dynamic arguments) {
    final status = arguments is Map ? arguments['status'] : arguments;
    _addLog('Print status update', 'info', details: 'Status: $status');
  }

  void _handlePrintProgressUpdate(dynamic arguments) {
    final progress = arguments is Map ? arguments['progress'] : arguments;
    _addLog('Print progress update', 'info', details: 'Progress: $progress');
  }

  void _handleSettingsComplete(dynamic arguments) {
    _addLog('Settings command completed', 'success',
        details: 'Settings updated successfully');
  }

  void _handleSettingsError(dynamic arguments) {
    _addLog('Settings command failed', 'error',
        details: 'Failed to update settings: $arguments');
  }

  void _handleConnectionStatusChanged(dynamic arguments) {
    final status = arguments is Map ? arguments['status'] : arguments;
    final color = arguments is Map ? arguments['color'] : 'unknown';
    _addLog('Connection status changed', 'info',
        details: 'Status: $status, Color: $color');
  }

  void _handleConnectionLost(dynamic arguments) {
    final reason = arguments is Map ? arguments['reason'] : 'Unknown reason';
    _addLog('Connection lost', 'warning', details: 'Connection lost: $reason');
    setState(() {
      _isPrinterConnected = false;
      _selectedDevice = null;
    });
  }

  void _handleDiscoveryWarning(dynamic arguments) {
    final phase = arguments is Map ? arguments['phase'] : 'unknown';
    final target = arguments is Map ? arguments['target'] : 'unknown';
    final message = arguments is Map ? arguments['message'] : 'Unknown warning';
    _addLog('Discovery warning', 'warning',
        details: 'Phase: $phase, Target: $target, Message: $message');
  }

  void _addLog(String message, String level, {String? details}) {
    if (!mounted) return;
    
    // Also log to console for debugging
    final fullMessage = details != null ? '$message - $details' : message;
    switch (level.toLowerCase()) {
      case 'error':
        _logger.error(fullMessage);
        break;
      case 'warning':
        _logger.warning(fullMessage);
        break;
      case 'info':
        _logger.info(fullMessage);
        break;
      case 'success':
        _logger.info('✅ $fullMessage');
        break;
      case 'debug':
        _logger.debug(fullMessage);
        break;
      default:
        _logger.info(fullMessage);
        break;
    }
    
    setState(() {
      _logs.add(LogEntry(
        timestamp: DateTime.now(),
        level: level,
        message: message,
        details: details,
      ));
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
    _addLog('Logs cleared', 'info');
  }

  Future<void> _startDiscovery() async {
    _addLog('_startDiscovery called', 'debug');

    if (_printerChannel == null) {
      _addLog('Cannot start discovery: printer channel is null', 'error');
      return;
    }

    if (_isDiscovering) {
      _addLog('Discovery already in progress', 'warning');
      return;
    }

    _addLog('Setting discovery state to true', 'debug');
    setState(() {
      _isDiscovering = true;
      _devices.clear();
    });

    _addLog('Starting discovery...', 'info');
      
    try {
      _addLog('Calling printerChannel.startDiscovery()', 'debug');
      final result = await _printerChannel!.startDiscovery();
      _addLog('startDiscovery returned: $result', 'debug');
    } catch (e) {
      _addLog('Discovery error', 'error', details: '$e');
      setState(() {
        _isDiscovering = false;
      });
    }
  }

  Future<void> _connectToDevice(DirectDevice device) async {
    _addLog('_connectToDevice called', 'debug');
    _addLog('Device: ${device.name} (${device.address})', 'debug');

    if (_printerChannel == null) {
      _addLog('Cannot connect: printer channel is null', 'error');
      return;
    }

    _addLog('Connecting to ${device.name}...', 'info');

    try {
      _addLog('Calling printerChannel.connectToPrinter()', 'debug');
      final result = await _printerChannel!.connectToPrinter(device.address);
      _addLog('connectToPrinter returned: $result', 'debug');
      
      if (result) {
        _addLog('Connection successful, updating state', 'debug');
        setState(() {
          _selectedDevice = device;
          _isPrinterConnected = true;
        });
        _addLog('Connected successfully', 'success');
      } else {
        _addLog('Connection failed', 'error');
      }
    } catch (e) {
      _addLog('Connection error', 'error', details: '$e');
    }
  }

  Future<void> _connectManual() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      _addLog('Please enter an IP address', 'warning');
      return;
    }

    final device = DirectDevice(
      address: ip,
      name: 'Manual Printer ($ip)',
      isWifi: true,
    );

    await _connectToDevice(device);
  }

  Future<void> _disconnect() async {
    if (_printerChannel == null) return;

    _addLog('Disconnecting...', 'info');

    try {
      await _printerChannel!.disconnect();
      setState(() {
        _selectedDevice = null;
        _isPrinterConnected = false;
      });
      _addLog('Disconnected', 'success');
    } catch (e) {
      _addLog('Disconnect error', 'error', details: '$e');
    }
  }

  Future<void> _print() async {
    _addLog('_print called', 'debug');
    
    if (!_isPrinterConnected || _printerChannel == null) {
      _addLog('Not connected to printer', 'warning');
      return;
    }

    _addLog('Setting printing state to true', 'debug');
    setState(() {
      _isPrinting = true;
    });

    _addLog('Preparing print data...', 'info', 
      details: 'Format: ${_format.name}, Size: ${_dataController.text.length} bytes');

    try {
      String preparedData = _dataController.text;
      _addLog('Original data length: ${preparedData.length}', 'debug');
      
      // CPCL data preparation (same as library implementation)
      if (_format == PrintFormat.cpcl) {
        _addLog('Preparing CPCL data...', 'debug');
        preparedData = preparedData.replaceAll(RegExp(r'(?<!\r)\n'), '\r\n');
        _addLog(
            'After line ending replacement: ${preparedData.length}', 'debug');

        if (preparedData.trim().endsWith('FORM') &&
            !preparedData.contains('PRINT')) {
          preparedData = '${preparedData.trim()}\r\nPRINT\r\n';
          _addLog('Added PRINT command', 'debug');
        }

        if (!preparedData.endsWith('\r\n')) {
          preparedData += '\r\n';
          _addLog('Added final line ending', 'debug');
        }

        preparedData += '\r\n\r\n';
        _addLog('Added final double line endings', 'debug');
      }

      _addLog('Final prepared data length: ${preparedData.length}', 'debug');
      _addLog('Sending data to printer...', 'info', 
        details: 'Format: ${_format.name}, Size: ${preparedData.length} bytes');

      // Send print data
      _addLog('Calling printerChannel.print()', 'debug');
      final result = await _printerChannel!.print(preparedData);
      _addLog('print returned: $result', 'debug');

      if (result) {
        _addLog('Print data sent', 'success');
        
        // CPCL buffer flush
        if (_format == PrintFormat.cpcl) {
          _addLog('Flushing CPCL buffer...', 'info');
          _addLog('Calling sendFlushCommand with \\x0C', 'debug');
          final flushResult = await _printerChannel!.sendFlushCommand('\x0C');
          _addLog('sendFlushCommand returned: $flushResult', 'debug');
          _addLog('Waiting 100ms after flush', 'debug');
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // Wait for completion
        final delay = Duration(
          milliseconds: 2500 + (preparedData.length ~/ 1000) * 1000
        );
        _addLog('Calculated delay: ${delay.inMilliseconds}ms', 'debug');
        _addLog('Waiting ${delay.inMilliseconds}ms for completion...', 'info');
        await Future.delayed(delay);

        _addLog('Print completed', 'success');
      } else {
        _addLog('Print failed', 'error');
      }
    } catch (e) {
      _addLog('Print error', 'error', details: '$e');
    } finally {
      if (mounted) {
        _addLog('Setting printing state to false', 'debug');
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    
    return ResponsiveContainer(
      maxWidth: 1200,
      child: isMobile
          ? _buildMobileLayout()
          : _buildTabletLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Connection card
        _buildConnectionCard(),
        const SizedBox(height: 16),
        // Print data editor
        Expanded(
          child: editor.PrintDataEditor(
            controller: _dataController,
            format: _format,
            onFormatChanged: (format) {
              setState(() {
                _format = format;
              });
            },
            onPrint: _isPrinterConnected && !_isPrinting ? _print : null,
            isPrinting: _isPrinting,
          ),
        ),
        const SizedBox(height: 16),
        // Log panel
        SizedBox(
          height: 200,
          child: LogPanel(
            logs: _logs,
            onClear: _clearLogs,
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Connection and logs
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Connection card
              _buildConnectionCard(),
              const SizedBox(height: 16),
              // Log panel
              Expanded(
                child: LogPanel(
                  logs: _logs,
                  onClear: _clearLogs,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Right side - Print data editor
        Expanded(
          flex: 3,
          child: editor.PrintDataEditor(
            controller: _dataController,
            format: _format,
            onFormatChanged: (format) {
              setState(() {
                _format = format;
              });
            },
            onPrint: _isPrinterConnected && !_isPrinting ? _print : null,
            isPrinting: _isPrinting,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cable,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Direct Channel Connection',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isPrinterConnected && _selectedDevice != null) ...[
              // Connected state
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connected to ${_selectedDevice!.name}',
                      style: TextStyle(color: Colors.grey[700]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _disconnect,
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
            ] else ...[
              // Discovery section
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isDiscovering || _printerChannel == null 
                          ? null
                          : _startDiscovery,
                      icon: _isDiscovering
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search),
                      label: Text(_isDiscovering ? 'Discovering...' : 'Discover'),
                    ),
                  ),
                ],
              ),
              // Device list
              if (_devices.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Found Devices:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ..._devices.map((device) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: () => _connectToDevice(device),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                          ),
                      child: Row(
                            children: [
                              Icon(
                            device.isWifi ? Icons.wifi : Icons.bluetooth,
                            size: 16,
                            color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                          Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                  device.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                ),
                                Text(
                                  device.address,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                              ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                )),
              ],
              // Manual IP entry
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Manual Connection:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        hintText: '192.168.1.100',
                        isDense: true,
                        contentPadding: EdgeInsets.all(12),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _connectManual,
                    child: const Text('Connect'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
} 