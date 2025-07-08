import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';

/// Example screen demonstrating the refactored SmartPrintManager
/// Shows proper architecture with ZebraPrinterService and instance-based events
class SmartPrintExampleScreen extends StatefulWidget {
  const SmartPrintExampleScreen({super.key});

  @override
  State<SmartPrintExampleScreen> createState() => _SmartPrintExampleScreenState();
}

class _SmartPrintExampleScreenState extends State<SmartPrintExampleScreen> {
  final ZebraPrinterService _service = ZebraPrinterService();
  StreamSubscription<PrintEvent>? _printEventSubscription;
  
  // UI State
  bool _isInitialized = false;
  bool _isPrinting = false;
  String _status = 'Initializing...';
  String _currentStep = '';
  String _errorMessage = '';
  bool _showErrorDetails = false;
  int _retryCount = 0;
  int _maxAttempts = 3;
  double _progress = 0.0;
  
  // Print data for testing
  final String _testZplData = '''
^XA
^FO50,50^A0N,50,50^FDHello Smart Print!^FS
^FO50,120^A0N,30,30^FDThis is a test print^FS
^FO50,160^A0N,25,25^FDUsing SmartPrintManager^FS
^XZ
''';

  final String _testCpclData = '''
! 0 200 200 400 1
TEXT 4 0 0 50 Hello Smart Print!
TEXT 4 0 0 100 This is a test print
TEXT 4 0 0 150 Using SmartPrintManager
FORM
PRINT
''';

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      setState(() {
        _status = 'Initializing ZebraPrinterService...';
      });
      
      await _service.initialize();
      
      setState(() {
        _isInitialized = true;
        _status = 'Ready to print';
      });
    } catch (e) {
      setState(() {
        _status = 'Initialization failed: $e';
      });
    }
  }

  Future<void> _startSmartPrint(String data, {ZebraDevice? device}) async {
    if (!_isInitialized) {
      setState(() {
        _status = 'Service not initialized';
      });
      return;
    }

    setState(() {
      _isPrinting = true;
      _status = 'Starting smart print...';
      _currentStep = '';
      _errorMessage = '';
      _showErrorDetails = false;
      _retryCount = 0;
      _progress = 0.0;
    });

    // Subscribe to print events
    _printEventSubscription?.cancel();
    _printEventSubscription = _service.smartPrint(
      data,
      device: device,
      maxAttempts: 3,
      connectionTimeout: const Duration(seconds: 10),
      printTimeout: const Duration(seconds: 30),
    ).listen(
      (event) {
        _handlePrintEvent(event);
      },
      onError: (error) {
        setState(() {
          _isPrinting = false;
          _status = 'Print error: $error';
          _errorMessage = error.toString();
        });
      },
    );
  }

  void _handlePrintEvent(PrintEvent event) {
    setState(() {
      switch (event.type) {
        case PrintEventType.stepChanged:
          _currentStep = event.stepInfo?.message ?? '';
          _status = _currentStep;
          _retryCount = event.stepInfo?.retryCount ?? 0;
          _maxAttempts = event.stepInfo?.maxAttempts ?? 3;
          _progress = event.stepInfo?.progress ?? 0.0;
          break;
          
        case PrintEventType.errorOccurred:
          _errorMessage = event.errorInfo?.message ?? 'Unknown error';
          _status = 'Error: $_errorMessage';
          break;
          
        case PrintEventType.retryAttempt:
          _retryCount = event.stepInfo?.retryCount ?? 0;
          _status = 'Retrying... (${_retryCount + 1}/$_maxAttempts)';
          break;
          
        case PrintEventType.progressUpdate:
          _progress = event.progressInfo?.progress ?? 0.0;
          _status = event.progressInfo?.currentOperation ?? _status;
          break;
          
        case PrintEventType.completed:
          _isPrinting = false;
          _status = 'Print completed successfully!';
          _progress = 1.0;
          break;
          
        case PrintEventType.cancelled:
          _isPrinting = false;
          _status = 'Print cancelled';
          break;
      }
    });
  }

  Future<void> _cancelPrint() async {
    await _service.cancelSmartPrint();
    setState(() {
      _isPrinting = false;
      _status = 'Print cancelled';
    });
  }

  @override
  void dispose() {
    _printEventSubscription?.cancel();
    _service.disposeSmartPrintManager();
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isInitialized ? Icons.check_circle : Icons.error,
                          color: _isInitialized ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Service Status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    if (_isPrinting) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _progress),
                      const SizedBox(height: 4),
                      Text('Progress: ${(_progress * 100).toInt()}%'),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Current Step Card
            if (_currentStep.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Step',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(_currentStep),
                      if (_retryCount > 0)
                        Text(
                          'Retry: $_retryCount/$_maxAttempts',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            
            if (_currentStep.isNotEmpty) const SizedBox(height: 16),
            
            // Error Card
            if (_errorMessage.isNotEmpty)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'Error',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      if (_errorMessage.length > 50) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showErrorDetails = !_showErrorDetails;
                            });
                          },
                          child: Text(_showErrorDetails ? 'Hide Details' : 'Show Details'),
                        ),
                        if (_showErrorDetails)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            
            if (_errorMessage.isNotEmpty) const SizedBox(height: 16),
            
            // Print Buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Print Options',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isPrinting ? null : () => _startSmartPrint(_testZplData),
                            icon: const Icon(Icons.print),
                            label: const Text('Print ZPL'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isPrinting ? null : () => _startSmartPrint(_testCpclData),
                            icon: const Icon(Icons.print),
                            label: const Text('Print CPCL'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isPrinting) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _cancelPrint,
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel Print'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            // Architecture Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Architecture',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Uses ZebraPrinterService for native operations\n'
                      '• Instance-based event streams (no global state)\n'
                      '• Automatic retry with error recovery\n'
                      '• Comprehensive error handling and user guidance',
                      style: TextStyle(fontSize: 12),
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