import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zebrautil/zebra.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'package:zebrautil/smart/options/smart_print_options.dart';
import 'package:zebrautil/smart/options/smart_batch_options.dart';
import 'package:zebrautil/smart/options/discovery_options.dart';
import 'package:zebrautil/internal/operation_manager.dart';

import 'bt_printer_selector.dart';
import 'operation_log_panel.dart';

enum PrintMode { cpcl, zpl, auto }

class SmartScreen extends StatefulWidget {
  const SmartScreen({super.key});

  @override
  State<SmartScreen> createState() => _SmartScreenState();
}

class _SmartScreenState extends State<SmartScreen> {
  ZebraDevice? _selectedDevice;
  bool _isConnected = false;
  String _status = 'Ready to print';
  bool _isPrinting = false;
  PrintMode _printMode = PrintMode.zpl;
  late TextEditingController _labelController;
  StreamSubscription<String>? _statusSubscription;
  StreamSubscription<ZebraDevice?>? _connectionSubscription;
  bool _isLoading = false;
  
  // Advanced options
  SmartPrintOptions _smartOptions = const SmartPrintOptions.reliable();
  bool _showAdvancedOptions = false;
  bool _enableConnectionPooling = true;
  bool _enableCaching = true;
  bool _enableOptimization = true;
  bool _clearBufferBeforePrint = true;
  bool _flushBufferAfterPrint = true;
  int _maxRetries = 3;
  double _retryDelay = 2.0;
  
  // Batch printing
  List<String> _batchLabels = [];
  bool _isBatchPrinting = false;

  // Logs
  final List<OperationLogEntry> _logs = [];
  
  // Sample data
  final String defaultZPL = """^XA
^LL250
^FO50,50^A0N,50,50^FDHello from Smart API!^FS
^FO50,100^BY2^BCN,100,Y,N,N^FD123456789^FS
^XZ""";

  final String defaultCPCL = """! 0 200 200 400 1
ON-FEED IGNORE
LABEL
CONTRAST 0
TONE 0
SPEED 5
PAGE-WIDTH 800
BAR-SENSE
T 7 1 550 91 Smart API Test
T 7 1 220 190 Advanced Features
T 7 1 550 42 6/27/2025
T 7 1 220 42 Smart Print
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

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: defaultZPL);
    _initPrinterState();
    _generateBatchLabels();
  }

  Future<void> _initPrinterState() async {
    _statusSubscription = Zebra.statusStream.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });
    _connectionSubscription = Zebra.connectionStream.listen((device) {
      if (mounted) {
        setState(() => _isConnected =
            device != null && device.address == _selectedDevice?.address);
      }
    });
  }

  void _generateBatchLabels() {
    _batchLabels = List.generate(5, (index) => 
      '^XA^FO50,50^A0N,50,50^FDBatch Label ${index + 1}^FS^XZ'
    );
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    _labelController.dispose();
    super.dispose();
  }

  void _onDeviceSelected(ZebraDevice device) {
    if (mounted) {
      setState(() => _selectedDevice = device);
    }
  }

  Future<void> _onConnect(ZebraDevice device) async {
    final result = await Zebra.smartConnect(device.address);
    if (mounted) {
      setState(() {
        _isConnected = result.success;
        _selectedDevice = device;
        _status = result.success
            ? 'Connected to ${device.name}'
            : 'Failed to connect: ${result.error?.message ?? "Unknown error"}';
      });
    }
  }

  void _onDisconnect() async {
    await Zebra.smartDisconnect();
    if (mounted) {
      setState(() {
        _isConnected = false;
        _status = 'Ready to print';
      });
    }
  }

  void _onPrintModeChanged(PrintMode mode) {
    if (mounted) {
      setState(() {
        _printMode = mode;
        if (mode == PrintMode.zpl) {
          _labelController.text = defaultZPL;
        } else if (mode == PrintMode.cpcl) {
          _labelController.text = defaultCPCL;
        }
      });
    }
  }

  void _addLog(String message, String level) {
    final log = OperationLogEntry(
      operationId: DateTime.now().millisecondsSinceEpoch.toString(),
      method: 'SmartAPI',
      status: level,
      timestamp: DateTime.now(),
      arguments: {'message': message},
    );
    
    setState(() {
      _logs.insert(0, log);
      if (_logs.length > 100) {
        _logs.removeLast();
      }
    });
  }

  Future<void> _smartPrint() async {
    if (mounted) {
      setState(() => _isPrinting = true);
    }

    _addLog('Starting smart print operation', 'INFO');

    try {
      // Update smart options based on UI settings
      _smartOptions = SmartPrintOptions(
        maxRetries: _maxRetries,
        retryDelay: Duration(seconds: _retryDelay.toInt()),
        clearBufferBeforePrint: _clearBufferBeforePrint,
        flushBufferAfterPrint: _flushBufferAfterPrint,
        enableConnectionPooling: _enableConnectionPooling,
        enableCaching: _enableCaching,
        enableOptimization: _enableOptimization,
      );

      final result = await Zebra.smartPrint(
        _labelController.text,
        address: _selectedDevice?.address,
        options: _smartOptions,
      );

      if (mounted) {
        setState(() {
          _isPrinting = false;
          _status = result.success
              ? 'Print successful'
              : 'Print failed: ${result.error?.message ?? "Unknown error"}';
        });
      }

      _addLog(
        result.success
            ? 'Smart print completed successfully'
            : 'Smart print failed: ${result.error?.message}',
        result.success ? 'SUCCESS' : 'ERROR',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPrinting = false;
          _status = 'Print error: $e';
        });
      }
      _addLog('Smart print error: $e', 'ERROR');
    }
  }

  Future<void> _smartBatchPrint() async {
    if (mounted) {
      setState(() => _isBatchPrinting = true);
    }

    _addLog('Starting smart batch print operation', 'INFO');

    try {
      final batchOptions = SmartBatchOptions(
        parallelProcessing: false, // Sequential for reliability
        batchDelay: const Duration(milliseconds: 500),
        maxRetries: _maxRetries,
        retryDelay: Duration(seconds: _retryDelay.toInt()),
      );

      final result = await Zebra.smartPrintBatch(
        _batchLabels,
        address: _selectedDevice?.address,
        options: batchOptions,
      );

      if (mounted) {
        setState(() {
          _isBatchPrinting = false;
          _status = result.success
              ? 'Batch print successful'
              : 'Batch print failed: ${result.error?.message ?? "Unknown error"}';
        });
      }

      _addLog(
        result.success
            ? 'Smart batch print completed successfully'
            : 'Smart batch print failed: ${result.error?.message}',
        result.success ? 'SUCCESS' : 'ERROR',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBatchPrinting = false;
          _status = 'Batch print error: $e';
        });
      }
      _addLog('Smart batch print error: $e', 'ERROR');
    }
  }

  Future<void> _getSmartStatus() async {
    try {
      final status = await Zebra.getSmartStatus();
      _addLog('Smart status retrieved: ${status.toString()}', 'INFO');
      
      if (mounted) {
        setState(() {
          _status = 'Smart API Status: ${status.connectionHealth}% healthy';
        });
      }
    } catch (e) {
      _addLog('Failed to get smart status: $e', 'ERROR');
    }
  }

  Future<void> _discoverPrinters() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    _addLog('Starting smart printer discovery', 'INFO');

    try {
      final result = await Zebra.smartDiscover(
        options: const DiscoveryOptions(
          timeout: Duration(seconds: 10),
          includeBluetooth: true,
          includeNetwork: true,
        ),
      );
      
      if (result.success) {
        _addLog('Smart discovery found ${result.data?.length ?? 0} printers',
            'SUCCESS');
      } else {
        _addLog('Smart discovery failed: ${result.error?.message}', 'ERROR');
      }
    } catch (e) {
      _addLog('Smart discovery error: $e', 'ERROR');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart API Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Printer Selection Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Printer Selection',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    
                    BTPrinterSelector(
                      onDeviceSelected: _onDeviceSelected,
                      onConnect: _onConnect,
                      onDisconnect: _onDisconnect,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Connection status
                    Card(
                      color: _isConnected
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Icon(
                              _isConnected ? Icons.check_circle : Icons.error,
                              color: _isConnected ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isConnected ? 'Connected' : 'Disconnected',
                                style: TextStyle(
                                  color: _isConnected
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Print Configuration Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Print Configuration',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),

                    // Print mode selector
                    Text('Print Mode:',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SegmentedButton<PrintMode>(
                      segments: const [
                        ButtonSegment(value: PrintMode.zpl, label: Text('ZPL')),
                        ButtonSegment(
                            value: PrintMode.cpcl, label: Text('CPCL')),
                        ButtonSegment(
                            value: PrintMode.auto, label: Text('Auto')),
                      ],
                      selected: {_printMode},
                      onSelectionChanged: (Set<PrintMode> selection) {
                        _onPrintModeChanged(selection.first);
                      },
                    ),
                    
                    const SizedBox(height: 16),

                    // Advanced options toggle
                    Row(
                      children: [
                        const Text('Advanced Options'),
                        const Spacer(),
                        Switch(
                          value: _showAdvancedOptions,
                          onChanged: (value) {
                            setState(() => _showAdvancedOptions = value);
                          },
                        ),
                      ],
                    ),

                    // Advanced options
                    if (_showAdvancedOptions) ...[
                      const SizedBox(height: 16),
                      Text('Smart Options:',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Connection Pooling'),
                            selected: _enableConnectionPooling,
                            onSelected: (value) =>
                                setState(
                                () => _enableConnectionPooling = value),
                          ),
                          FilterChip(
                            label: const Text('Caching'),
                            selected: _enableCaching,
                            onSelected: (value) =>
                                setState(() => _enableCaching = value),
                          ),
                          FilterChip(
                            label: const Text('Optimization'),
                            selected: _enableOptimization,
                            onSelected: (value) =>
                                setState(() => _enableOptimization = value),
                          ),
                          FilterChip(
                            label: const Text('Clear Buffer'),
                            selected: _clearBufferBeforePrint,
                            onSelected: (value) =>
                                setState(() => _clearBufferBeforePrint = value),
                          ),
                          FilterChip(
                            label: const Text('Flush Buffer'),
                            selected: _flushBufferAfterPrint,
                            onSelected: (value) =>
                                setState(() => _flushBufferAfterPrint = value),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Max Retries: $_maxRetries'),
                                Slider(
                                  value: _maxRetries.toDouble(),
                                  min: 1,
                                  max: 10,
                                  divisions: 9,
                                  onChanged: (value) => setState(
                                      () => _maxRetries = value.toInt()),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Retry Delay: ${_retryDelay.toStringAsFixed(1)}s'),
                                Slider(
                                  value: _retryDelay,
                                  min: 0.5,
                                  max: 5.0,
                                  divisions: 9,
                                  onChanged: (value) =>
                                      setState(() => _retryDelay = value),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actions',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),

                    // Action buttons in a grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 3,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _discoverPrinters,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                          label:
                              Text(_isLoading ? 'Discovering...' : 'Discover'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isPrinting ? null : _smartPrint,
                          icon: _isPrinting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.print),
                          label:
                              Text(_isPrinting ? 'Printing...' : 'Smart Print'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isBatchPrinting ? null : _smartBatchPrint,
                          icon: _isBatchPrinting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.batch_prediction),
                          label: Text(
                              _isBatchPrinting ? 'Batch...' : 'Batch Print'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _getSmartStatus,
                          icon: const Icon(Icons.analytics),
                          label: const Text('Status'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Print Data Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Print Data',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      height: 200,
                      child: TextField(
                        controller: _labelController,
                        maxLines: null,
                        expands: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter ZPL or CPCL data here...',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Status Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(_status,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Operation Logs Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operation Logs',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      height: 300,
                      child: OperationLogPanel(logs: _logs),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 