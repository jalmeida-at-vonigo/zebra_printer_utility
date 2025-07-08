import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';

import '../widgets/print_data_editor.dart' as editor;
import '../widgets/printer_selector.dart';
import '../widgets/log_panel.dart';
import '../widgets/responsive_layout.dart';

/// Smart print screen demonstrating event-driven print workflow
class SmartPrintScreen extends StatefulWidget {
  const SmartPrintScreen({super.key});

  @override
  State<SmartPrintScreen> createState() => _SmartPrintScreenState();
}

class _SmartPrintScreenState extends State<SmartPrintScreen> {
  final TextEditingController _dataController = TextEditingController();
  final List<LogEntry> _logs = [];
  
  ZebraDevice? _selectedPrinter;
  bool _isPrinting = false;
  editor.PrintFormat _format = editor.PrintFormat.zpl;
  String _status = 'Ready';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    // Set default ZPL data
    _dataController.text = '''^XA
^FO50,50^ADN,36,20^FDSmart Print Demo^FS
^FO50,120^BY3^BCN,100,Y,N,N^FD123456789^FS
^FO50,250^ADN,18,10^FDPowered by Flutter^FS
^XZ''';
    _addLog('Smart print screen initialized', 'info');
  }

  @override
  void dispose() {
    _dataController.dispose();
    super.dispose();
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

  Future<void> _smartPrint() async {
    if (_selectedPrinter == null) {
      _addLog('No printer selected', 'warning');
      return;
    }

    setState(() {
      _isPrinting = true;
      _progress = 0.0;
      _status = 'Initializing...';
    });

    try {
      _addLog('Starting smart print workflow...', 'info');
      
      // Smart print with event stream
      final eventStream = Zebra.smartPrint(
        _dataController.text,
        device: _selectedPrinter!,
        maxAttempts: 3,
        options: PrintOptions(
          format: _format == editor.PrintFormat.zpl ? PrintFormat.zpl : PrintFormat.cpcl,
        ),
      );

      await for (final event in eventStream) {
        if (!mounted) break;
        
        _handlePrintEvent(event);
      }
    } catch (e, stack) {
      _addLog('Smart print error', 'error', details: '$e\n$stack');
      setState(() {
        _status = 'Error occurred';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  void _handlePrintEvent(PrintEvent event) {
    switch (event.type) {
      case PrintEventType.stepChanged:
        if (event.stepInfo != null) {
          setState(() {
            _status = event.stepInfo!.message;
            _progress = event.stepInfo!.progress;
          });
          _addLog(
            'Step: ${event.stepInfo!.step.toString().split('.').last}',
            'info',
            details: event.stepInfo!.message,
          );
        }
        break;
        
      case PrintEventType.progressUpdate:
        if (event.progressInfo != null) {
          setState(() {
            _status = event.progressInfo!.currentOperation;
            _progress = event.progressInfo!.progress;
          });
        }
        break;
        
      case PrintEventType.errorOccurred:
        if (event.errorInfo != null) {
          _addLog(
            'Error occurred',
            'error',
            details: '${event.errorInfo!.message}\n'
                'Recoverability: ${event.errorInfo!.recoverability.toString().split('.').last}',
          );
          setState(() {
            _status = 'Error: ${event.errorInfo!.message}';
          });
        }
        break;
        
      case PrintEventType.retryAttempt:
        _addLog(
          'Retry attempt',
          'warning',
          details: 'Attempt ${event.metadata['attempt']} of ${event.metadata['maxAttempts']}',
        );
        break;
        
      case PrintEventType.realTimeStatusUpdate:
        final hasIssues = event.metadata['hasIssues'] as bool? ?? false;
        final progressHint = event.metadata['progressHint'] as String?;
        final issueDetails = event.metadata['issueDetails'] as List?;
        
        if (progressHint != null) {
          setState(() {
            _status = progressHint;
          });
        }
        
        if (hasIssues && issueDetails != null && issueDetails.isNotEmpty) {
          _addLog(
            'Status update',
            'warning',
            details: 'Issues detected: ${issueDetails.join(', ')}',
          );
        }
        break;
        
      case PrintEventType.completed:
        setState(() {
          _status = 'Print completed successfully!';
          _progress = 1.0;
        });
        _addLog('Print completed', 'success');
        break;
        
      case PrintEventType.cancelled:
        setState(() {
          _status = 'Print cancelled';
          _progress = 0.0;
        });
        _addLog('Print cancelled', 'warning');
        break;
        
      default:
        break;
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
        // Status card
        _buildStatusCard(),
        const SizedBox(height: 16),
        // Printer selector
        SizedBox(
          height: 180,
          child: PrinterSelector(
            onPrinterChanged: (printer) {
              setState(() {
                _selectedPrinter = printer;
              });
            },
            onLog: _addLog,
          ),
        ),
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
            onPrint: _selectedPrinter != null && !_isPrinting ? _smartPrint : null,
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
        // Left side - Status, printer selector and logs
        SizedBox(
          width: 350,
          child: Column(
            children: [
              // Status card
              _buildStatusCard(),
              const SizedBox(height: 16),
              // Printer selector
              SizedBox(
                height: 250,
                child: PrinterSelector(
                  onPrinterChanged: (printer) {
                    setState(() {
                      _selectedPrinter = printer;
                    });
                  },
                  onLog: _addLog,
                ),
              ),
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
          child: editor.PrintDataEditor(
            controller: _dataController,
            format: _format,
            onFormatChanged: (format) {
              setState(() {
                _format = format;
              });
            },
            onPrint: _selectedPrinter != null && !_isPrinting ? _smartPrint : null,
            isPrinting: _isPrinting,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.smart_button,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Smart Print Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _status,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _isPrinting ? _progress : 0.0,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _progress >= 1.0 ? Colors.green : Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 