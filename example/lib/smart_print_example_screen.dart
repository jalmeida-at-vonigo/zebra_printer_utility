import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';
import 'package:zebrautil/internal/operation_manager.dart';
import 'operation_log_panel.dart';

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

      // Listen to status messages
      _manager!.status.listen((message) {
        _addLog('Status', 'info', message);
      });

      _addLog('Manager', 'success', 'Manager initialized successfully');
    } catch (e) {
      _addLog('Manager', 'error', 'Error initializing manager: $e');
    }
  }

  Future<void> _startSmartPrint() async {
    if (_manager == null) {
      _addLog('Print', 'error', 'Manager not initialized');
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
      // Start smart print and get event stream
      final eventStream = _manager!.smartPrint(
        _dataController.text.trim(),
        maxAttempts: 3,
        timeout: const Duration(seconds: 30),
      );

      // Listen to print events
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
    // Check if widget is still mounted
    if (!mounted) return;

    // Check if manager is still available
    if (_manager == null) return;
    
    // Update UI based on the simple status
    setState(() {
      _currentStatus = event.status.displayName;
      if (event.message != null) {
        _currentStatus += ': ${event.message}';
      }

      // Update progress based on status
      switch (event.status) {
        case PrintStatus.connecting:
          _progress = 0.25;
          break;
        case PrintStatus.configuring:
          _progress = 0.5;
          break;
        case PrintStatus.printing:
          _progress = 0.75;
          break;
        case PrintStatus.done:
          _progress = 1.0;
          _isPrinting = false;
          break;
        case PrintStatus.failed:
        case PrintStatus.cancelled:
          _progress = 0.0;
          _isPrinting = false;
          break;
      }
    });

    // Handle specific event types for logging
    switch (event.type) {
      case PrintEventType.stepChanged:
        _handleStepChange(event);
        break;
      case PrintEventType.errorOccurred:
        _handleError(event.errorInfo!);
        break;
      case PrintEventType.retryAttempt:
        _handleRetry(event);
        break;
      case PrintEventType.realTimeStatusUpdate:
        _handleRealTimeStatusUpdate(event);
        break;
      case PrintEventType.completed:
        _handleCompletion();
        break;
      case PrintEventType.cancelled:
        _handleCancellation();
        break;
      default:
        // Handle other event types
        break;
    }
  }

  void _handleStepChange(PrintEvent event) {
    if (!mounted) return;
    _addLog(
        'Step', 'info', '${event.status.displayName}: ${event.message ?? ''}');
  }

  void _handleError(PrintErrorInfo errorInfo) {
    if (!mounted) return;
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

  void _handleRetry(PrintEvent event) {
    if (!mounted) return;
    _addLog('Retry', 'warning', event.message ?? 'Retry attempt');
  }

  void _handleRealTimeStatusUpdate(PrintEvent event) {
    if (!mounted) return;
    // Handle real-time status updates from printer polling
    final status = event.metadata['status'] as Map<String, dynamic>?;
    final issues = event.metadata['issues'] as List<String>?;
    final canAutoResume = event.metadata['canAutoResume'] as bool?;

    if (status != null) {
      final isCompleted = status['isCompleted'] as bool? ?? false;
      final hasIssues = status['hasIssues'] as bool? ?? false;

      if (isCompleted) {
        _addLog('Status', 'success', 'Print completed successfully!');
      } else if (hasIssues && issues != null && issues.isNotEmpty) {
        _addLog('Status', 'warning', 'Issues detected: ${issues.join(', ')}');
      } else if (canAutoResume == true) {
        _addLog('Status', 'info', 'Printer can be auto-resumed');
      } else {
        _addLog('Status', 'info', 'Waiting for print completion...');
      }
    }
  }

  void _handleCompletion() {
    if (!mounted) return;
    setState(() {
      _currentStatus = 'Print completed successfully!';
      _progress = 1.0;
    });
    _addLog('Print', 'success', 'Print operation completed successfully');
  }

  void _handleCancellation() {
    if (!mounted) return;
    setState(() {
      _currentStatus = 'Print cancelled';
      _progress = 0.0;
    });
    _addLog('Print', 'warning', 'Print operation was cancelled');
  }

  void _cancelPrint() {
    if (_manager == null) return;

    try {
      _manager!.cancelSmartPrint();
      _addLog('Print', 'warning', 'Print cancellation requested');
    } catch (e) {
      _addLog('Print', 'error', 'Error cancelling print: $e');
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

      // Keep only last 50 logs
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
    // Cancel subscriptions first
    _printEventSubscription?.cancel();
    _printEventSubscription = null;

    // Cancel any ongoing operations before disposing
    if (_manager != null) {
      try {
        _manager!.cancelSmartPrint();
      } catch (e) {
        // Ignore errors during cleanup
      }

      // Dispose the manager
      try {
        _manager!.dispose();
      } catch (e) {
        // Ignore errors during cleanup
      }
      _manager = null;
    }

    // Dispose controllers
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