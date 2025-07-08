import 'package:flutter/material.dart';

/// Print data format
enum PrintFormat { zpl, cpcl }

/// Preset print data templates
class PrintPreset {
  final String name;
  final String description;
  final PrintFormat format;
  final String data;

  const PrintPreset({
    required this.name,
    required this.description,
    required this.format,
    required this.data,
  });
}

// Default presets
const List<PrintPreset> defaultPresets = [
  // ZPL Presets
  PrintPreset(
    name: 'Simple Text',
    description: 'Basic ZPL text label',
    format: PrintFormat.zpl,
    data: '''^XA
^FO50,50^FDHello World^FS
^XZ''',
  ),
  PrintPreset(
    name: 'Barcode Label',
    description: 'ZPL label with barcode',
    format: PrintFormat.zpl,
    data: '''^XA
^FO50,50^ADN,36,20^FDProduct Label^FS
^FO50,100^BY3^BCN,100,Y,N,N^FD123456789^FS
^FO50,250^ADN,18,10^FDItem: 123456789^FS
^XZ''',
  ),
  PrintPreset(
    name: 'Test Pattern',
    description: 'ZPL test pattern',
    format: PrintFormat.zpl,
    data: '''^XA
^FO0,0^GB812,1218,3^FS
^FO10,10^GB792,1198,3^FS
^FO50,50^ADN,36,20^FDZebra Printer Test^FS
^FO50,150^ADN,18,10^FDModel: ^FS^FO200,150^ADN,18,10^FN1^FS
^FO50,200^ADN,18,10^FDSerial: ^FS^FO200,200^ADN,18,10^FN2^FS
^FO50,300^BY3^BCN,100,Y,N,N^FD123456789^FS
^XZ''',
  ),
  // CPCL Presets
  PrintPreset(
    name: 'Simple Text',
    description: 'Basic CPCL text label',
    format: PrintFormat.cpcl,
    data: '''! 0 200 200 210 1
TEXT 4 0 30 40 Hello from Flutter!
TEXT 4 0 30 100 Test Label
TEXT 4 0 30 160 CPCL Mode
FORM
PRINT''',
  ),
  PrintPreset(
    name: 'Receipt',
    description: 'CPCL receipt format',
    format: PrintFormat.cpcl,
    data: '''! 0 200 200 400 1
CENTER
TEXT 4 0 0 20 RECEIPT
TEXT 4 0 0 60 ----------------
LEFT
TEXT 4 0 10 100 Item 1          \$10.00
TEXT 4 0 10 130 Item 2          \$15.00
TEXT 4 0 10 160 Item 3          \$25.00
TEXT 4 0 10 190 ----------------
TEXT 4 0 10 220 TOTAL           \$50.00
CENTER
BARCODE 128 1 1 50 0 280 123456789
TEXT 4 0 0 350 Thank You!
FORM
PRINT''',
  ),
  PrintPreset(
    name: 'Label with Logo',
    description: 'CPCL label with graphics',
    format: PrintFormat.cpcl,
    data: '''! 0 200 200 400 1
ON-FEED IGNORE
LABEL
CONTRAST 0
TONE 0
SPEED 5
PAGE-WIDTH 800
BAR-SENSE
TEXT 7 1 220 42 Product Name
TEXT 7 1 220 91 SKU: 12345
TEXT 7 1 220 140 Price: \$99.99
TEXT 4 0 220 190 Description Line 1
TEXT 4 0 220 220 Description Line 2
CENTER 800
BARCODE 128 1 1 50 0 280 123456789012
LEFT
FORM
PRINT''',
  ),
];

/// A reusable print data editor widget with format selection and presets
class PrintDataEditor extends StatefulWidget {
  final TextEditingController controller;
  final PrintFormat format;
  final ValueChanged<PrintFormat>? onFormatChanged;
  final VoidCallback? onPrint;
  final bool isPrinting;

  const PrintDataEditor({
    super.key,
    required this.controller,
    required this.format,
    this.onFormatChanged,
    this.onPrint,
    this.isPrinting = false,
  });

  @override
  State<PrintDataEditor> createState() => _PrintDataEditorState();
}

class _PrintDataEditorState extends State<PrintDataEditor> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _applyPreset(PrintPreset preset) {
    widget.controller.text = preset.data;
    if (widget.onFormatChanged != null && preset.format != widget.format) {
      widget.onFormatChanged!(preset.format);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with format selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.code,
                      size: 20,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Print Data',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const Spacer(),
                    // Format selector
                    SegmentedButton<PrintFormat>(
                      segments: const [
                        ButtonSegment(
                          value: PrintFormat.zpl,
                          label: Text('ZPL'),
                          icon: Icon(Icons.qr_code),
                        ),
                        ButtonSegment(
                          value: PrintFormat.cpcl,
                          label: Text('CPCL'),
                          icon: Icon(Icons.receipt),
                        ),
                      ],
                      selected: {widget.format},
                      onSelectionChanged: (selection) {
                        if (widget.onFormatChanged != null && selection.isNotEmpty) {
                          widget.onFormatChanged!(selection.first);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Presets
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final preset in defaultPresets
                          .where((p) => p.format == widget.format))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(preset.name),
                            onPressed: () => _applyPreset(preset),
                            tooltip: preset.description,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Editor
          Expanded(
            child: TextField(
              controller: widget.controller,
              maxLines: null,
              expands: true,
              scrollController: _scrollController,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: widget.format == PrintFormat.zpl
                    ? 'Enter ZPL commands here...\n\nExample:\n^XA\n^FO50,50^FDHello World^FS\n^XZ'
                    : 'Enter CPCL commands here...\n\nExample:\n! 0 200 200 210 1\nTEXT 4 0 30 40 Hello World\nFORM\nPRINT',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          // Print button
          if (widget.onPrint != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: widget.isPrinting ? null : widget.onPrint,
                  icon: widget.isPrinting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print),
                  label: Text(widget.isPrinting ? 'Printing...' : 'Print'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 