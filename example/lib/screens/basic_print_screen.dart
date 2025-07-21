import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';

import '../widgets/responsive_layout.dart';
import '../widgets/print_data_editor.dart' as editor;
import '../widgets/printer_selector.dart';
import '../widgets/log_panel.dart';
import '../widgets/mobile_tabbed_layout.dart';

/// Basic print example using Zebra.print()
class BasicPrintScreen extends StatefulWidget {
  const BasicPrintScreen({super.key});

  @override
  State<BasicPrintScreen> createState() => _BasicPrintScreenState();
}

class _BasicPrintScreenState extends State<BasicPrintScreen> {
  final _dataController = TextEditingController();
  editor.PrintFormat _format = editor.PrintFormat.zpl;
  bool _isPrinting = false;
  final List<LogEntry> _logs = [];
  ZebraDevice? _selectedPrinter;

  @override
  void initState() {
    super.initState();
    // Set default data based on format
    _dataController.text = '''^XA
^FO50,50^FDHello World^FS
^XZ''';
    _addLog('Basic print example initialized', 'info');
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

  Future<void> _print() async {
    if (_selectedPrinter == null) {
      _addLog('No printer selected', 'warning');
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    try {
      _addLog('Starting print operation...', 'info');
      
      // Simple print using Zebra.print()
      final printOptions = PrintOptions(
        format: _format == editor.PrintFormat.zpl ? PrintFormat.zpl : PrintFormat.cpcl,
      );
      
      _addLog('Sending data to printer...', 'info', 
        details: 'Format: ${_format.name}, Size: ${_dataController.text.length} bytes');
      
      final result = await Zebra.print(
        _dataController.text,
        options: printOptions,
      );

      if (result.success) {
        _addLog('Print completed successfully', 'success');
      } else {
        _addLog('Print failed', 'error', details: result.error?.message);
      }
    } catch (e, stack) {
      _addLog('Print error', 'error', details: '$e\n$stack');
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
    
    return isMobile
        ? MobileTabbedLayout(
            dataController: _dataController,
            format: _format,
            onFormatChanged: (format) {
              setState(() {
                _format = format;
              });
            },
            onPrint: _selectedPrinter != null && !_isPrinting ? _print : null,
            isPrinting: _isPrinting,
            logs: _logs,
            onLog: _addLog,
            onClearLogs: _clearLogs,
            onPrinterChanged: (printer) {
              setState(() {
                _selectedPrinter = printer;
              });
            },
            selectedPrinter: _selectedPrinter,
          )
        : _buildTabletLayout();
  }

  Widget _buildTabletLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column - Printer and logs
          Expanded(
            flex: 1,
            child: Column(
              children: [
                // Printer selector (fixed height)
                SizedBox(
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
                const SizedBox(height: 16),
                // Log panel (remaining space)
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
          // Right column - Print data editor
          Expanded(
            flex: 2,
            child: editor.PrintDataEditor(
              controller: _dataController,
              format: _format,
              onFormatChanged: (format) {
                setState(() {
                  _format = format;
                });
              },
              onPrint: _selectedPrinter != null && !_isPrinting ? _print : null,
              isPrinting: _isPrinting,
            ),
          ),
        ],
      ),
    );
  }
} 