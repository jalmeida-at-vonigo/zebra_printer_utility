import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';

import '../widgets/print_data_editor.dart' as editor;
import '../widgets/printer_selector.dart';
import '../widgets/log_panel.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/mobile_tabbed_layout.dart';

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
  editor.PrintFormat _format = editor.PrintFormat.zpl;
  
  // Local copy of PrintState from events
  PrintState? _printState;

  // Smart print manager for cancellation support
  SmartPrintManager? _smartPrintManager;

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

    try {
      _addLog('Starting smart print workflow...', 'info');
      
      // Create SmartPrintManager instance for cancellation support
      _smartPrintManager = SmartPrintManager(Zebra.manager);
      
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
      // No need to manually update state - event stream handles it
    }
  }

  void _cancelPrint() {
    if (_smartPrintManager?.canCancel == true) {
      _addLog('Cancelling print operation...', 'warning');
      _smartPrintManager!.cancel();
    }
  }







  void _handlePrintEvent(PrintEvent event) {
    // Update state from event
    if (event.printState != null) {
      setState(() {
        _printState = event.printState as PrintState;
      });
    }

    switch (event.type) {
      case PrintEventType.stepChanged:
        if (event.stepInfo != null) {
          _addLog(
            'Step: ${event.stepInfo!.step.toString().split('.').last}',
            'info',
            details: event.stepInfo!.message,
          );
        }
        break;
        
      case PrintEventType.progressUpdate:
        // Use event state for accurate logging
        final eventState = event.printState as PrintState?;
        _addLog(
          'Progress update',
          'info',
          details:
              'Progress: ${((eventState?.getProgress() ?? 0) * 100).toStringAsFixed(1)}%',
        );
        break;
        
      case PrintEventType.errorOccurred:
        if (event.errorInfo != null) {
          _addLog(
            'Error occurred',
            'error',
            details: '${event.errorInfo!.message}\n'
                'Recoverability: ${event.errorInfo!.recoverability.toString().split('.').last}',
          );
        }
        break;
        
      case PrintEventType.retryAttempt:
        final eventState = event.printState as PrintState?;
        _addLog(
          'Retry attempt',
          'warning',
          details:
              'Attempt ${eventState?.retryCount ?? 0} of ${eventState?.maxAttempts ?? 1}',
        );
        break;
        

        
      case PrintEventType.completed:
        _addLog('Print completed', 'success');
        break;
        
      case PrintEventType.cancelled:
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
          ? MobileTabbedLayout(
              dataController: _dataController,
              format: _format,
              onFormatChanged: (format) {
                setState(() {
                  _format = format;
                });
              },
              onPrint: _selectedPrinter != null &&
                      !(_printState?.isPrinting ?? false)
                  ? _smartPrint
                  : null,
              isPrinting: _printState?.isPrinting ?? false,
              logs: _logs,
              onLog: _addLog,
              onClearLogs: _clearLogs,
              onPrinterChanged: (printer) {
                setState(() {
                  _selectedPrinter = printer;
                });
              },
              selectedPrinter: _selectedPrinter,
              statusWidget: _buildStatusCard(),
            )
          : _buildTabletLayout(),
    );
  }

  Widget _buildTabletLayout() {
    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top section - Status card (full width)
          _buildStatusCard(),
          const SizedBox(height: 16),
          // Middle section - Print data editor (full width)
          editor.PrintDataEditor(
            controller: _dataController,
            format: _format,
            onFormatChanged: (format) {
              setState(() {
                _format = format;
              });
            },
            onPrint:
                _selectedPrinter != null && !(_printState?.isPrinting ?? false)
                    ? _smartPrint
                    : null,
            isPrinting: _printState?.isPrinting ?? false,
          ),
          const SizedBox(height: 16),
          // Bottom section - Printer selector and logs
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Printer selector
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 320, // Fixed height for printer selector
                    child: PrinterSelector(
                      onPrinterChanged: (printer) {
                        setState(() {
                          _selectedPrinter = printer;
                        });
                      },
                      onLog: _addLog,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Right side - Log panel
                Expanded(
                  flex: 2,
                  child: LogPanel(
                    logs: _logs,
                    onClear: _clearLogs,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _printState?.currentMessage ?? 'Ready';
    final progress = _printState?.currentStep.progress ?? 0.0;
    final isPrinting = _printState?.isPrinting ?? false;
    final isCompleted = _printState?.isCompleted ?? false;
    final currentStep = _printState?.currentStep;

    final canCancel = _smartPrintManager?.canCancel ?? false;
    
    Color stepColor(PrintStep step) {
      switch (step) {
        case PrintStep.initializing:
        case PrintStep.validating:
          return Colors.blue;
        case PrintStep.connecting:
        case PrintStep.connected:
          return Colors.cyan;
        case PrintStep.checkingStatus:
          return Colors.indigo;
        case PrintStep.sending:
        case PrintStep.waitingForCompletion:
          return Colors.orange;
        case PrintStep.completed:
          return Colors.green;
        case PrintStep.failed:
          return Colors.red;
        case PrintStep.cancelled:
          return Colors.grey;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status icon, title, step badge, and cancel button
            Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  size: 20,
                  color: _getStatusColor(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Smart Print Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                if (currentStep != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: stepColor(currentStep),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      currentStep.displayName,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (canCancel) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _cancelPrint,
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Enhanced status display
            Text(
              status,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            // Enhanced progress indicator with attempt info
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        if (_printState?.isRetrying == true) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Retry ${_printState!.retryCount}/${_printState!.maxAttempts}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: isPrinting ? progress : (isCompleted ? 1.0 : 0.0),
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted ? Colors.green : Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            // Rich real-time status information
            if (_printState != null) ...[
              const SizedBox(height: 12),
              _buildRichStateInfo(_printState!),
            ],


          ],
        ),
      ),
    );
  }

  // Helper methods for enhanced status display
  IconData _getStatusIcon() {
    if (_printState?.isCompleted == true) return Icons.check_circle;
    if (_printState?.hasFailed == true) return Icons.error;
    if (_printState?.isPrinting == true) return Icons.print;
    if (_printState?.currentError != null) return Icons.warning;
    return Icons.smart_button;
  }

  Color _getStatusColor() {
    if (_printState?.isCompleted == true) return Colors.green;
    if (_printState?.hasFailed == true) return Colors.red;
    if (_printState?.isPrinting == true) return Theme.of(context).primaryColor;
    if (_printState?.currentError != null) return Colors.orange;
    return Theme.of(context).primaryColor;
  }

  Widget _buildRichStateInfo(PrintState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current step and attempt info
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              'Step: ${state.currentStep.toString().split('.').last}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (state.isRetrying) ...[
              const SizedBox(width: 12),
              Text(
                'Retry ${state.retryCount} of ${state.maxAttempts}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),


        // Elapsed time
        if (state.startTime != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.timer,
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Elapsed: ${_formatDuration(state.elapsedTime)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }



  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }


} 