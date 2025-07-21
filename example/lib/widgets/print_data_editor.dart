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

  Widget _buildFormatToggle() {
    return SegmentedButton<PrintFormat>(
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
          final newFormat = selection.first;
          widget.onFormatChanged!(newFormat);

          // Automatically apply a template for the new format
          final presetsForNewFormat =
              defaultPresets.where((p) => p.format == newFormat).toList();
          if (presetsForNewFormat.isNotEmpty) {
            // Apply the first template for the new format
            _applyPreset(presetsForNewFormat.first);
          }
        }
      },
    );
  }

  Widget _buildPresetSelector() {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final preset
              in defaultPresets.where((p) => p.format == widget.format))
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.edit_document,
                      size: 20,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Print Data',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    // Fullscreen button for mobile
                    if (MediaQuery.of(context).size.width < 600)
                      IconButton(
                        icon: const Icon(Icons.fullscreen),
                        tooltip: 'Full screen editor',
                        onPressed: () => _openFullscreenEditor(context),
                      ),
                    // Format toggle
                    _buildFormatToggle(),
                  ],
                ),
                const SizedBox(height: 12),
                // Preset selector
                _buildPresetSelector(),
              ],
            ),
          ),
          // Code editor
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(4)),
              ),
              child: TextField(
                controller: widget.controller,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Enter ${widget.format.name.toUpperCase()} data here...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),
          // Print button
          if (widget.onPrint != null)
            Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: widget.onPrint,
                icon: widget.isPrinting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.print),
                label: Text(widget.isPrinting ? 'Printing...' : 'Print'),
              ),
            ),
        ],
      ),
    );
  }

  void _openFullscreenEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _FullscreenEditor(
          controller: widget.controller,
          format: widget.format,
          onFormatChanged: widget.onFormatChanged ?? ((_) {}),
        ),
      ),
    );
  }
}

class _FullscreenEditor extends StatelessWidget {
  final TextEditingController controller;
  final PrintFormat format;
  final ValueChanged<PrintFormat> onFormatChanged;

  const _FullscreenEditor({
    required this.controller,
    required this.format,
    required this.onFormatChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${format.name.toUpperCase()} Editor'),
        actions: [
          // Format toggle
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<PrintFormat>(
              segments: const [
                ButtonSegment(
                  value: PrintFormat.zpl,
                  label: Text('ZPL'),
                ),
                ButtonSegment(
                  value: PrintFormat.cpcl,
                  label: Text('CPCL'),
                ),
              ],
              selected: {format},
              onSelectionChanged: (Set<PrintFormat> selected) {
                if (selected.isNotEmpty) {
                  final newFormat = selected.first;
                  onFormatChanged(newFormat);

                  // Automatically apply a template for the new format
                  final presetsForNewFormat = defaultPresets
                      .where((p) => p.format == newFormat)
                      .toList();
                  if (presetsForNewFormat.isNotEmpty) {
                    // Apply the first template for the new format
                    controller.text = presetsForNewFormat.first.data;
                  }
                }
              },
            ),
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[100],
        child: TextField(
          controller: controller,
          maxLines: null,
          expands: true,
          autofocus: true,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Enter ${format.name.toUpperCase()} data here...',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ),
    );
  }
} 