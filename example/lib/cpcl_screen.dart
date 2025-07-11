import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';
import 'bt_printer_selector.dart';
import 'operation_log_panel.dart';

/// CPCL Test Screen
///
/// Demonstrates manual CPCL label editing and direct printing with device selection.
/// This screen shows how to use the primitive API for direct control over CPCL commands.
///
/// Features:
/// - Manual CPCL label editing with syntax highlighting
/// - Device discovery and connection
/// - Direct print operations using primitive API
/// - Real-time status updates
/// - Shared log panel for debugging
class CPCLScreen extends StatefulWidget {
  const CPCLScreen({super.key});

  @override
  State<CPCLScreen> createState() => _CPCLScreenState();
}

class _CPCLScreenState extends State<CPCLScreen> {
  final TextEditingController _cpclController = TextEditingController();
  final List<OperationLogEntry> _logs = [];
  ZebraPrinterManager? _manager;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeManager();
    _loadDefaultCPCL();
  }

  @override
  void dispose() {
    _manager?.dispose();
    _cpclController.dispose();
    super.dispose();
  }

  void _initializeManager() {
    _manager = ZebraPrinterManager();
    _addLog('CPCL Screen initialized', 'completed');
  }

  void _loadDefaultCPCL() {
    _cpclController.text = '''! 0 200 200 300 1
CENTER
T 7 0 0 100 Sample CPCL Label
T 7 0 0 150 This is a test label
FORM
PRINT''';
    _addLog('Default CPCL template loaded', 'completed');
  }

  void _addLog(String message, String status) {
    setState(() {
      _logs.add(OperationLogEntry(
        operationId: DateTime.now().millisecondsSinceEpoch.toString(),
        method: 'CPCLScreen',
        status: status,
        timestamp: DateTime.now(),
      ));
      if (_logs.length > 100) {
        _logs.removeAt(0);
      }
    });
  }

  Future<void> _connectToPrinter(ZebraDevice device) async {
    _addLog('Attempting to connect to ${device.address}', 'started');

    try {
      final result = await _manager!.connect(device);
      if (result.success) {
        setState(() {
          _isConnected = true;
        });
        _addLog('Successfully connected to ${device.address}', 'completed');
      } else {
        _addLog('Failed to connect: ${result.error}', 'failed');
      }
    } catch (e) {
      _addLog('Connection error: $e', 'failed');
    }
  }

  Future<void> _disconnect() async {
    if (!_isConnected) return;

    _addLog('Disconnecting from printer', 'started');

    try {
      await _manager!.disconnect();
      setState(() {
        _isConnected = false;
      });
      _addLog('Successfully disconnected', 'completed');
    } catch (e) {
      _addLog('Disconnect error: $e', 'failed');
    }
  }

  Future<void> _printCPCL() async {
    if (!_isConnected) {
      _addLog('No printer connected', 'failed');
      return;
    }

    final cpclData = _cpclController.text.trim();
    if (cpclData.isEmpty) {
      _addLog('No CPCL data to print', 'failed');
      return;
    }

    _addLog('Sending CPCL data to printer', 'started');

    try {
      // Use the primitive API for direct CPCL control
      // This demonstrates manual control over the printing process
      final result = await _manager!.print(cpclData);
      
      if (result.success) {
        _addLog('CPCL print completed successfully', 'completed');
      } else {
        _addLog('Print failed: ${result.error?.message ?? 'Unknown error'}',
            'failed');
      }
    } catch (e) {
      _addLog('Print error: $e', 'failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CPCL Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Connection Status and Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: BTPrinterSelector(
                        onDeviceSelected: _connectToPrinter,
                        onConnect: _connectToPrinter,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isConnected ? _disconnect : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _isConnected ? 'Connected' : 'Disconnected',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // CPCL Editor
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.code, size: 16),
                        const SizedBox(width: 8),
                        const Text('CPCL Editor',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _isConnected ? _printCPCL : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Print'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _cpclController,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                        hintText: 'Enter CPCL commands here...',
                      ),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Log Panel
          Expanded(
            flex: 1,
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
