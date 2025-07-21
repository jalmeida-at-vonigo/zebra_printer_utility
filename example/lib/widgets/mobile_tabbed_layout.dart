import 'package:flutter/material.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'print_data_editor.dart' as editor;
import 'printer_selector.dart';
import 'log_panel.dart';

class MobileTabbedLayout extends StatefulWidget {
  final TextEditingController dataController;
  final editor.PrintFormat format;
  final ValueChanged<editor.PrintFormat> onFormatChanged;
  final VoidCallback? onPrint;
  final bool isPrinting;
  final List<LogEntry> logs;
  final Function(String, String, {String? details}) onLog;
  final VoidCallback onClearLogs;
  final ValueChanged<ZebraDevice?> onPrinterChanged;
  final ZebraDevice? selectedPrinter;
  final Widget? statusWidget;

  const MobileTabbedLayout({
    super.key,
    required this.dataController,
    required this.format,
    required this.onFormatChanged,
    required this.onPrint,
    required this.isPrinting,
    required this.logs,
    required this.onLog,
    required this.onClearLogs,
    required this.onPrinterChanged,
    this.selectedPrinter,
    this.statusWidget,
  });

  @override
  State<MobileTabbedLayout> createState() => _MobileTabbedLayoutState();
}

class _MobileTabbedLayoutState extends State<MobileTabbedLayout> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        // Optional status widget
        if (widget.statusWidget != null) ...[
          widget.statusWidget!,
          const SizedBox(height: 8),
        ],
        // Tab bar with printer status
        Container(
          color: theme.primaryColor.withValues(alpha: 0.1),
          child: Column(
            children: [
              // Printer status bar
              if (widget.selectedPrinter != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Connected: ${widget.selectedPrinter!.name}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              // Tab bar
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    icon: Icon(
                      Icons.print,
                      size: 20,
                      color: widget.selectedPrinter == null && _currentIndex == 0
                          ? Colors.orange
                          : null,
                    ),
                    text: 'Printer',
                  ),
                  const Tab(
                    icon: Icon(Icons.edit_document, size: 20),
                    text: 'Data',
                  ),
                  Tab(
                    icon: Stack(
                      children: [
                        const Icon(Icons.list_alt, size: 20),
                        if (widget.logs.any((log) => log.level.toLowerCase() == 'error'))
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    text: 'Logs',
                  ),
                ],
                labelColor: theme.primaryColor,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: theme.primaryColor,
                labelPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Printer tab
              Padding(
                padding: const EdgeInsets.all(16),
                child: PrinterSelector(
                  onPrinterChanged: widget.onPrinterChanged,
                  onLog: widget.onLog,
                ),
              ),
              // Data tab
              Padding(
                padding: const EdgeInsets.all(16),
                child: editor.PrintDataEditor(
                  controller: widget.dataController,
                  format: widget.format,
                  onFormatChanged: widget.onFormatChanged,
                  onPrint: widget.onPrint,
                  isPrinting: widget.isPrinting,
                ),
              ),
              // Logs tab
              Padding(
                padding: const EdgeInsets.all(16),
                child: LogPanel(
                  logs: widget.logs,
                  onClear: widget.onClearLogs,
                ),
              ),
            ],
          ),
        ),
        // Print button (always visible)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                offset: const Offset(0, -1),
                blurRadius: 4,
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onPrint,
                icon: widget.isPrinting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.print),
                label: Text(widget.isPrinting ? 'Printing...' : 'Print'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
} 