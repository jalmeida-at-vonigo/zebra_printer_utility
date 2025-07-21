import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/print_data_editor.dart' as editor;
import '../widgets/log_panel.dart';
import '../widgets/responsive_layout.dart';

/// Direct MethodChannel wrapper for Zebra printer operations
/// Demonstrates direct native platform calls bypassing the library
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

  Future<bool> startDiscovery() async {
    if (_instanceChannel == null) return false;
    try {
      await _instanceChannel.invokeMethod('startScan');
      return true;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Discovery error: $e');
      return false;
    }
  }

  Future<bool> stopDiscovery() async {
    if (_instanceChannel == null) return false;
    try {
      await _instanceChannel.invokeMethod('stopScan');
      return true;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Stop discovery error: $e');
      return false;
    }
  }

  Future<bool> connectToPrinter(String address) async {
    if (_instanceChannel == null) return false;
    try {
      final result = await _instanceChannel.invokeMethod<bool>(
        'connectToPrinter',
        {'Address': address},
      );
      return result == true;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Connection error: $e');
      return false;
    }
  }

  Future<bool> disconnect() async {
    if (_instanceChannel == null) return false;
    try {
      await _instanceChannel.invokeMethod('disconnect');
      return true;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Disconnect error: $e');
      return false;
    }
  }

  Future<bool> print(String data) async {
    if (_instanceChannel == null) return false;
    try {
      final result = await _instanceChannel.invokeMethod<bool>(
        'print',
        {'Data': data},
      );
      return result == true;
    } catch (e) {
      debugPrint('DirectPrinterChannel: Print error: $e');
      return false;
    }
  }

  Future<bool> sendDataWithResponse(String data, {int timeout = 1000}) async {
    if (_instanceChannel == null) return false;
    try {
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
  
  DirectPrinterChannel? _printerChannel;
  DirectDevice? _selectedDevice;
  bool _isConnected = false;
  bool _isPrinting = false;
  bool _isDiscovering = false;
  editor.PrintFormat _format = editor.PrintFormat.cpcl;

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
      _printerChannel = await DirectPrinterChannel.createInstance(_handleMethodCall);
      
      if (_printerChannel != null) {
        _addLog('Channel initialized', 'success', 
          details: 'Instance ID: ${_printerChannel!.getInstanceId}');
      } else {
        _addLog('Failed to initialize channel', 'error');
      }
    } catch (e) {
      _addLog('Initialization error', 'error', details: '$e');
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'printerFound':
        _handlePrinterFound(call.arguments);
        break;
      case 'onDiscoveryDone':
        _handleDiscoveryDone();
        break;
      case 'onDiscoveryError':
        _addLog('Discovery error', 'error', details: '${call.arguments}');
        break;
    }
  }

  void _handlePrinterFound(dynamic arguments) {
    if (arguments is Map<dynamic, dynamic>) {
      final device = DirectDevice.fromMap(arguments);
      if (!_devices.any((d) => d.address == device.address)) {
        setState(() {
          _devices.add(device);
        });
        _addLog('Printer found', 'info', 
          details: '${device.name} (${device.address})');
      }
    }
  }

  void _handleDiscoveryDone() {
    setState(() {
      _isDiscovering = false;
    });
    _addLog('Discovery completed', 'success', 
      details: 'Found ${_devices.length} printer(s)');
  }

  void _addLog(String message, String level, {String? details}) {
    if (!mounted) return;
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
    if (_printerChannel == null || _isDiscovering) return;

    setState(() {
      _isDiscovering = true;
      _devices.clear();
    });

    _addLog('Starting discovery...', 'info');
      
    try {
      await _printerChannel!.startDiscovery();
    } catch (e) {
      _addLog('Discovery error', 'error', details: '$e');
      setState(() {
        _isDiscovering = false;
      });
    }
  }

  Future<void> _connectToDevice(DirectDevice device) async {
    if (_printerChannel == null) return;

    _addLog('Connecting to ${device.name}...', 'info');

    try {
      final result = await _printerChannel!.connectToPrinter(device.address);
      
      if (result) {
        setState(() {
          _selectedDevice = device;
          _isConnected = true;
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
        _isConnected = false;
      });
      _addLog('Disconnected', 'success');
    } catch (e) {
      _addLog('Disconnect error', 'error', details: '$e');
    }
  }

  Future<void> _print() async {
    if (!_isConnected || _printerChannel == null) {
      _addLog('Not connected to printer', 'warning');
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    _addLog('Preparing print data...', 'info', 
      details: 'Format: ${_format.name}, Size: ${_dataController.text.length} bytes');

    try {
      String preparedData = _dataController.text;
      
      // CPCL data preparation (same as library implementation)
      if (_format == editor.PrintFormat.cpcl) {
        preparedData = preparedData.replaceAll(RegExp(r'(?<!\r)\n'), '\r\n');

        if (preparedData.trim().endsWith('FORM') &&
            !preparedData.contains('PRINT')) {
          preparedData = '${preparedData.trim()}\r\nPRINT\r\n';
        }

        if (!preparedData.endsWith('\r\n')) {
          preparedData += '\r\n';
        }

        preparedData += '\r\n\r\n';
      }

      _addLog('Sending data to printer...', 'info', 
        details: 'Format: ${_format.name}, Size: ${preparedData.length} bytes');

      // Send print data
      final result = await _printerChannel!.print(preparedData);

      if (result) {
        _addLog('Print data sent', 'success');
        
        // CPCL buffer flush
        if (_format == editor.PrintFormat.cpcl) {
          _addLog('Flushing CPCL buffer...', 'info');
          await _printerChannel!.sendDataWithResponse('\x0C', timeout: 1000);
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // Wait for completion
        final delay = Duration(
          milliseconds: 2500 + (preparedData.length ~/ 1000) * 1000
        );
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
            onPrint: _isConnected && !_isPrinting ? _print : null,
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
            onPrint: _isConnected && !_isPrinting ? _print : null,
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
            if (_isConnected && _selectedDevice != null) ...[
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