import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';

import '../widgets/print_data_editor.dart' as editor;
import '../widgets/printer_selector.dart';
import '../widgets/log_panel.dart';
import '../widgets/responsive_layout.dart';

/// Basic print screen demonstrating simple print operations
class BasicPrintScreen extends StatefulWidget {
  const BasicPrintScreen({super.key});

  @override
  State<BasicPrintScreen> createState() => _BasicPrintScreenState();
}

class _BasicPrintScreenState extends State<BasicPrintScreen> {
  final TextEditingController _dataController = TextEditingController();
  final List<LogEntry> _logs = [];
  
  ZebraDevice? _selectedPrinter;
  bool _isPrinting = false;
  editor.PrintFormat _format = editor.PrintFormat.zpl;

  @override
  void initState() {
    super.initState();
    // Set default ZPL data
    _dataController.text = '''^XA
^FO50,50^FDHello World^FS
^XZ''';
    _addLog('Screen initialized', 'info');
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
        // Printer selector
        SizedBox(
          height: 200,
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
            onPrint: _selectedPrinter != null && !_isPrinting ? _print : null,
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
        // Left side - Printer selector and logs
        SizedBox(
          width: 350,
          child: Column(
            children: [
              // Printer selector
              SizedBox(
                height: 300,
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
            onPrint: _selectedPrinter != null && !_isPrinting ? _print : null,
            isPrinting: _isPrinting,
          ),
        ),
      ],
    );
  }
} 