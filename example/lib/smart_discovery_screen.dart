import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';
import 'operation_log_panel.dart';
import 'package:zebrautil/internal/operation_manager.dart';

class SmartDiscoveryScreen extends StatefulWidget {
  const SmartDiscoveryScreen({super.key});

  @override
  State<SmartDiscoveryScreen> createState() => _SmartDiscoveryScreenState();
}

class _SmartDiscoveryScreenState extends State<SmartDiscoveryScreen> {
  final List<ZebraDevice> _discoveredPrinters = [];
  final List<OperationLogEntry> _logs = [];
  bool _isScanning = false;
  ZebraPrinterManager? _manager;
  StreamSubscription<List<ZebraDevice>>? _discoverySubscription;

  @override
  void initState() {
    super.initState();
    _initializeManager();
  }

  Future<void> _initializeManager() async {
    try {
      _manager = ZebraPrinterManager();
      await _manager!.initialize();
      
      // Listen to discovery events
      _discoverySubscription = _manager!.discovery.devices.listen((devices) {
        setState(() {
          _discoveredPrinters.clear();
          _discoveredPrinters.addAll(devices);
        });
        _addLog(
            'Discovery', 'Success', 'Discovered ${devices.length} printers');
      });

      // Listen to status messages
      _manager!.status.listen((message) {
        _addLog('Status', 'Info', 'Status: $message');
      });

      _addLog('Manager', 'Success', 'Manager initialized successfully');
    } catch (e) {
      _addLog('Manager', 'Error', 'Error initializing manager: $e');
    }
  }

  Future<void> _startSmartDiscovery() async {
    if (_manager == null) {
      _addLog('Discovery', 'Error', 'Manager not initialized');
      return;
    }

    setState(() {
      _isScanning = true;
      _discoveredPrinters.clear();
    });

    _addLog('Discovery', 'Info', 'Starting smart discovery...');

    try {
      // Use smart discovery with streaming
      final discoveryStream = _manager!.discovery.discoverPrintersStream(
        timeout: const Duration(seconds: 15),
        stopAfterCount: 5, // Stop after finding 5 printers
        includeWifi: true,
        includeBluetooth: true,
      );

      await for (final devices in discoveryStream) {
        setState(() {
          _discoveredPrinters.clear();
          _discoveredPrinters.addAll(devices);
        });
        _addLog('Discovery', 'Success', 'Found ${devices.length} printers');
      }

      _addLog('Discovery', 'Success', 'Smart discovery completed');
    } catch (e) {
      _addLog('Discovery', 'Error', 'Discovery error: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _stopDiscovery() async {
    if (_manager == null) return;

    try {
      await _manager!.discovery.stopDiscovery();
      setState(() {
        _isScanning = false;
      });
      _addLog('Discovery', 'Success', 'Discovery stopped');
    } catch (e) {
      _addLog('Discovery', 'Error', 'Error stopping discovery: $e');
    }
  }

  Future<void> _connectToPrinter(ZebraDevice printer) async {
    if (_manager == null) return;

    _addLog('Connection', 'Info',
        'Connecting to ${printer.name} (${printer.address})...');

    try {
      final result = await _manager!.connect(printer);
      
      if (result.success) {
        _addLog('Connection', 'Success',
            'Successfully connected to ${printer.name}');
      } else {
        _addLog('Connection', 'Error',
            'Failed to connect: ${result.error?.message}');
      }
    } catch (e) {
      _addLog('Connection', 'Error', 'Connection error: $e');
    }
  }

  void _addLog(String method, String status, String message) {
    if (!mounted) return;
    
    setState(() {
      _logs.add(OperationLogEntry(
        operationId: DateTime.now().millisecondsSinceEpoch.toString(),
        method: method,
        status: status,
        timestamp: DateTime.now(),
        arguments: null,
        result: null,
        duration: null,
        error: message,
      ));
      if (_logs.length > 50) {
        _logs.removeAt(0);
      }
    });
  }

  @override
  void dispose() {
    // Cancel subscriptions first
    _discoverySubscription?.cancel();
    _discoverySubscription = null;

    // Stop discovery and dispose manager
    if (_manager != null) {
      try {
        _manager!.discovery.stopDiscovery();
      } catch (e) {
        // Ignore errors during cleanup
      }

      try {
        _manager!.dispose();
      } catch (e) {
        // Ignore errors during cleanup
      }
      _manager = null;
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Discovery'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Control Panel
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isScanning ? null : _startSmartDiscovery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                        _isScanning ? 'Scanning...' : 'Start Smart Discovery'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isScanning ? _stopDiscovery : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Stop Discovery'),
                  ),
                ),
              ],
            ),
          ),
          
          // Discovered Printers
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discovered Printers (${_discoveredPrinters.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _discoveredPrinters.isEmpty
                        ? const Center(
                            child: Text(
                              'No printers discovered yet.\nTap "Start Smart Discovery" to begin.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _discoveredPrinters.length,
                            itemBuilder: (context, index) {
                              final printer = _discoveredPrinters[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(
                                    printer.isWifi
                                        ? Icons.wifi
                                        : Icons.bluetooth,
                                    color: printer.isWifi
                                        ? Colors.blue
                                        : Colors.blue,
                                  ),
                                  title: Text(printer.name),
                                  subtitle: Text(printer.address),
                                  trailing: ElevatedButton(
                                    onPressed: () => _connectToPrinter(printer),
                                    child: const Text('Connect'),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          
          // Log Panel
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            child: OperationLogPanel(
              logs: _logs,
              onClearLogs: () {
                setState(() {
                  _logs.clear();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
} 