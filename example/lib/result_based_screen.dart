import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zebrautil/internal/operation_manager.dart';

import 'operation_log_panel.dart';

class ResultBasedScreen extends StatefulWidget {
  const ResultBasedScreen({super.key});

  @override
  State<ResultBasedScreen> createState() => _ResultBasedScreenState();
}

class _ResultBasedScreenState extends State<ResultBasedScreen> {
  late OperationManager _operationManager;
  List<OperationLogEntry> _logs = [];
  String _lastResult = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _operationManager = OperationManager(
      channel: const MethodChannel('test_channel'),
      onLog: (message) {
        debugPrint('OperationManager: $message');
      },
      onOperationLog: (entry) {
        setState(() {
          _logs = List.from(_operationManager.operationLog);
        });
      },
    );
  }

  @override
  void dispose() {
    _operationManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result-Based Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Control Panel
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Operation Controls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testSuccessOperation,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Success'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testFailureOperation,
                          icon: const Icon(Icons.error),
                          label: const Text('Failure'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testTimeoutOperation,
                          icon: const Icon(Icons.timer),
                          label: const Text('Timeout'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testConcurrentOperations,
                          icon: const Icon(Icons.sync),
                          label: const Text('Concurrent'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_lastResult.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Last Result:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(_lastResult),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Log Panel
            Expanded(
              child: OperationLogPanel(
                logs: _logs,
                onClearLogs: _clearLogs,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testSuccessOperation() async {
    setState(() {
      _isLoading = true;
      _lastResult = '';
    });

    try {
      final result = await _operationManager.execute<String>(
        method: 'successMethod',
        arguments: {'test': 'success_value', 'timestamp': DateTime.now().toIso8601String()},
        timeout: const Duration(seconds: 5),
      );

      setState(() {
        _lastResult = result.success 
            ? '✅ Success: ${result.data}'
            : '❌ Failed: ${result.error?.message}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testFailureOperation() async {
    setState(() {
      _isLoading = true;
      _lastResult = '';
    });

    try {
      final result = await _operationManager.execute<String>(
        method: 'failureMethod',
        arguments: {'test': 'failure_value', 'shouldFail': true},
        timeout: const Duration(seconds: 5),
      );

      setState(() {
        _lastResult = result.success 
            ? '✅ Success: ${result.data}'
            : '❌ Failed: ${result.error?.message}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testTimeoutOperation() async {
    setState(() {
      _isLoading = true;
      _lastResult = '';
    });

    try {
      final result = await _operationManager.execute<String>(
        method: 'timeoutMethod',
        arguments: {'test': 'timeout_value', 'delay': 10000},
        timeout: const Duration(milliseconds: 500),
      );

      setState(() {
        _lastResult = result.success 
            ? '✅ Success: ${result.data}'
            : '⏰ Timeout: ${result.error?.message}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testConcurrentOperations() async {
    setState(() {
      _isLoading = true;
      _lastResult = '';
    });

    try {
      final futures = [
        _operationManager.execute<String>(
          method: 'concurrentMethod1',
          arguments: {'id': 1, 'delay': 1000},
          timeout: const Duration(seconds: 3),
        ),
        _operationManager.execute<String>(
          method: 'concurrentMethod2',
          arguments: {'id': 2, 'delay': 2000},
          timeout: const Duration(seconds: 3),
        ),
        _operationManager.execute<String>(
          method: 'concurrentMethod3',
          arguments: {'id': 3, 'delay': 3000},
          timeout: const Duration(seconds: 3),
        ),
      ];

      final results = await Future.wait(futures);
      
      final successCount = results.where((r) => r.success).length;
      final failureCount = results.where((r) => !r.success).length;

      setState(() {
        _lastResult = '🔄 Concurrent Results: $successCount success, $failureCount failures';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearLogs() {
    _operationManager.clearLog();
    setState(() {
      _logs = [];
      _lastResult = '';
    });
  }
} 