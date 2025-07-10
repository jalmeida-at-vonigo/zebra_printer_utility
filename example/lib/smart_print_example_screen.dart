import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';
import 'package:zebrautil/internal/operation_manager.dart';
import 'operation_log_panel.dart';
import 'bt_printer_selector.dart';

/// Example screen demonstrating the refactored SmartPrintManager
/// Shows proper architecture with ZebraPrinterService and instance-based events
class SmartPrintExampleScreen extends StatefulWidget {
  const SmartPrintExampleScreen({super.key});

  @override
  State<SmartPrintExampleScreen> createState() => _SmartPrintExampleScreenState();
}

class _SmartPrintExampleScreenState extends State<SmartPrintExampleScreen> {
  final List<OperationLogEntry> _logs = [];
  final TextEditingController _dataController = TextEditingController();
  ZebraPrinterManager? _manager;
  StreamSubscription<PrintEvent>? _printEventSubscription;
  bool _isPrinting = false;
  String _currentStatus = 'Ready';
  double _progress = 0.0;
  ZebraDevice? _selectedPrinter;
  bool _isConnected = false;
  String _printerStatus = '';

  @override
  void initState() {
    super.initState();
    _initializeManager();
    _dataController.text = '''
^XA
^FO50,50
^ADN,36,20
^FDSmart Print Example
^FS
^FO50,100
^ADN,36,20
^FDEvent-Driven Printing
^FS
^FO50,150
^ADN,36,20
^FDWith Real-time Updates
^FS
^XZ
''';
  }

  Future<void> _initializeManager() async {
    try {
      _manager = ZebraPrinterManager();
      await _manager!.initialize();
      _manager!.status.listen((message) {
        setState(() {
          _printerStatus = message;
        });
        _addLog('Status', 'info', message);
      });
      _addLog('Manager', 'success', 'Manager initialized successfully');
    } catch (e) {
      _addLog('Manager', 'error', 'Error initializing manager: $e');
    }
  }

  Future<void> _handleConnect(ZebraDevice device) async {
    setState(() {
      _selectedPrinter = device;
      _isConnected = false;
    });
    final result = await _manager?.connect(device);
    setState(() {
      _isConnected = result?.success ?? false;
    });
    if (result?.success ?? false) {
      _addLog('Printer', 'success',
          'Connected to printer: ${device.name} (${device.address})');
    } else {
      _addLog('Printer', 'error',
          'Failed to connect: ${result?.error?.message ?? 'Unknown error'}');
    }
  }

  void _handleDisconnect() async {
    await _manager?.disconnect();
    setState(() {
      _isConnected = false;
      _selectedPrinter = null;
    });
    _addLog('Printer', 'info', 'Disconnected from printer');
  }

  Future<void> _startSmartPrint() async {
    if (_manager == null) {
      _addLog('Print', 'error', 'Manager not initialized');
      return;
    }
    if (!_isConnected || _selectedPrinter == null) {
      _addLog('Print', 'error',
          'No printer connected. Please connect to a printer first.');
      return;
    }
    if (_dataController.text.trim().isEmpty) {
      _addLog('Print', 'error', 'No print data provided');
      return;
    }
    setState(() {
      _isPrinting = true;
      _currentStatus = 'Initializing...';
      _progress = 0.0;
    });
    _addLog('Print', 'info', 'Starting smart print operation');
    try {
      final eventStream = Zebra.smartPrint(
        _dataController.text.trim(),
        device: _selectedPrinter,
        maxAttempts: 3,
        timeout: const Duration(seconds: 30),
      );
      _printEventSubscription = eventStream.listen(
        (event) {
          _handlePrintEvent(event);
        },
        onError: (error) {
          _addLog('Print', 'error', 'Print event error: $error');
          setState(() {
            _isPrinting = false;
            _currentStatus = 'Error occurred';
          });
        },
        onDone: () {
          _addLog('Print', 'info', 'Print event stream completed');
          setState(() {
            _isPrinting = false;
          });
        },
      );
    } catch (e) {
      _addLog('Print', 'error', 'Error starting smart print: $e');
      setState(() {
        _isPrinting = false;
        _currentStatus = 'Error occurred';
      });
    }
  }

  void _handlePrintEvent(PrintEvent event) {
    switch (event.type) {
      case PrintEventType.stepChanged:
        _handleStepChange(event.stepInfo!);
        break;
      case PrintEventType.errorOccurred:
        _handleError(event.errorInfo!);
        break;
      case PrintEventType.retryAttempt:
        _handleRetry(event.stepInfo!);
        break;
      case PrintEventType.progressUpdate:
        _handleProgress(event.progressInfo!);
        break;
      case PrintEventType.completed:
        _handleCompletion();
        break;
      case PrintEventType.cancelled:
        _handleCancellation();
        break;
    }
  }

  void _handleStepChange(PrintStepInfo stepInfo) {
    setState(() {
      _currentStatus = stepInfo.message;
      _progress = stepInfo.progress;
    });
    _addLog('Step', 'info', '${stepInfo.step.name}: ${stepInfo.message}');
    if (stepInfo.isRetry) {
      _addLog('Retry', 'warning',
          'Retry ${stepInfo.retryCount} of ${stepInfo.maxAttempts - 1}');
    }
  }

  void _handleError(PrintErrorInfo errorInfo) {
    setState(() {
      _currentStatus = 'Error: ${errorInfo.message}';
    });
    _addLog('Error', 'error',
        '${errorInfo.message} (${errorInfo.recoverability.name})');
    if (errorInfo.recoverability == ErrorRecoverability.nonRecoverable) {
      _addLog('Error', 'error',
          'Non-recoverable error - manual intervention required');
    }
  }

  void _handleRetry(PrintStepInfo stepInfo) {
    _addLog('Retry', 'warning', 'Retry attempt ${stepInfo.retryCount}');
  }

  void _handleProgress(PrintProgressInfo progressInfo) {
    setState(() {
      _progress = progressInfo.progress;
      _currentStatus = progressInfo.currentOperation;
    });
  }

  void _handleCompletion() {
    setState(() {
      _currentStatus = 'Print completed successfully!';
      _progress = 1.0;
    });
    _addLog('Print', 'success', 'Print operation completed successfully');
  }

  void _handleCancellation() {
    setState(() {
      _currentStatus = 'Print cancelled';
      _progress = 0.0;
    });
    _addLog('Print', 'warning', 'Print operation was cancelled');
  }

  void _cancelPrint() {
    if (_manager == null) return;
    try {
      Zebra.cancelSmartPrint();
      _addLog('Print', 'warning', 'Print cancellation requested');
    } catch (e) {
      _addLog('Print', 'error', 'Error cancelling print: $e');
    }
  }

  void _addLog(String method, String status, String message) {
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

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  void dispose() {
    _printEventSubscription?.cancel();
    _manager?.dispose();
    _dataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Print Example'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Printer Selector at the top
          BTPrinterSelector(
            onDeviceSelected: (device) {
              setState(() {
                _selectedPrinter = device;
              });
            },
            onConnect: (device) async {
              await _handleConnect(device);
            },
            onDisconnect: _handleDisconnect,
            selectedDevice: _selectedPrinter,
            isConnected: _isConnected,
            status: _printerStatus,
          ),
          // Status Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: $_currentStatus',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_isPrinting) ...[
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.grey[300],
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Progress: ${(_progress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          // Control Panel
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isPrinting ? null : _startSmartPrint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child:
                        Text(_isPrinting ? 'Printing...' : 'Start Smart Print'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isPrinting ? _cancelPrint : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Cancel Print'),
                  ),
                ),
              ],
            ),
          ),
          // Print Data Input
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Print Data (ZPL):',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _dataController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter ZPL code here...',
                  ),
                ),
              ],
            ),
          ),
          // Log Panel
          Expanded(
            child: OperationLogPanel(
              logs: _logs,
              onClearLogs: _clearLogs,
            ),
          ),
        ],
      ),
    );
  }
} 