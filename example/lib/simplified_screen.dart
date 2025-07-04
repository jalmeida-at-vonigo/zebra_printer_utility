import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';
import 'bt_printer_selector.dart';
import 'log_widget.dart';

enum PrintMode { cpcl, zpl, auto }

class SimplifiedScreen extends StatefulWidget {
  const SimplifiedScreen({super.key});

  @override
  State<SimplifiedScreen> createState() => _SimplifiedScreenState();
}

class _SimplifiedScreenState extends State<SimplifiedScreen> {
  ZebraDevice? _selectedDevice;
  bool _isConnected = false;
  String _status = 'Ready to print';
  bool _isPrinting = false;
  PrintMode _printMode = PrintMode.zpl;
  late TextEditingController _labelController;
  StreamSubscription<String>? _statusSubscription;
  StreamSubscription<ZebraDevice?>? _connectionSubscription;
  bool _isLoading = false;
  
  // Logs
  final List<SimpleLogEntry> _logs = [];

  final String defaultZPL = """^XA
^LL250
^FO50,50^A0N,50,50^FDHello from Flutter!^FS
^FO50,100^BY2^BCN,100,Y,N,N^FD123456789^FS
^XZ""";

  final String defaultCPCL = """! 0 200 200 400 1
ON-FEED IGNORE
LABEL
CONTRAST 0
TONE 0
SPEED 5
PAGE-WIDTH 800
BAR-SENSE
T 7 1 550 91 Bedroom 2 test value
T 7 1 220 190 Equalizer
T 7 1 550 42 6/27/2025
T 7 1 220 42 Test Jane
T 4 0 220 91 104
CENTER 800
BT 0 4 8
B 39 1 1 50 0 237 00170000010422
BT OFF
LEFT 0
T 4 0 88 169 689
FORM
PRINT
""";

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: defaultZPL);
    _initPrinterState();
  }

  Future<void> _initPrinterState() async {
    _statusSubscription = Zebra.statusStream.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });
    _connectionSubscription = Zebra.connectionStream.listen((device) {
      if (mounted) {
        setState(() => _isConnected =
            device != null && device.address == _selectedDevice?.address);
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    _labelController.dispose();
    super.dispose();
  }

  void _onDeviceSelected(ZebraDevice device) {
    if (mounted) {
      setState(() => _selectedDevice = device);
    }
  }

  Future<void> _onConnect(ZebraDevice device) async {
    final result = await Zebra.smartConnect(device.address);
    if (mounted) {
      setState(() {
        _isConnected = result.success;
        _selectedDevice = device;
        _status = result.success
            ? 'Connected to ${device.name}'
            : 'Failed to connect: ${result.error?.message ?? "Unknown error"}';
      });
    }
  }

  void _onDisconnect() {
    if (mounted) {
      setState(() {
        _isConnected = false;
        _status = 'Ready to print';
      });
    }
  }

  void _onPrintModeChanged(PrintMode mode) {
    if (mounted) {
      setState(() {
        _printMode = mode;
        if (mode == PrintMode.zpl) {
          _labelController.text = defaultZPL;
        } else if (mode == PrintMode.cpcl) {
          _labelController.text = defaultCPCL;
        }
        // For Auto mode, keep current text
      });
    }
  }

  Future<void> _print() async {
    if (mounted) {
      setState(() => _isPrinting = true);
    }

    _addLog('Starting print operation', 'INFO');

    PrintFormat? format;
    if (_printMode == PrintMode.zpl) {
      format = PrintFormat.zpl;
    } else if (_printMode == PrintMode.cpcl) {
      format = PrintFormat.cpcl;
    }
    // For Auto mode, format is null (auto-detected)

    Result<void> result;

    if (_isConnected && _selectedDevice != null) {
      _addLog('Using connected printer: ${_selectedDevice!.address}', 'INFO');
      // Use autoPrint with the connected printer
      result = await Zebra.autoPrint(
        _labelController.text,
        address: _selectedDevice!.address,
        format: format,
        disconnectAfter: false,
      );
    } else {
      _addLog('Auto-discovering printer', 'INFO');
      // Use autoPrint to discover and use any available printer
      result = await Zebra.autoPrint(
        _labelController.text,
        format: format,
      );
    }

    if (mounted) {
      setState(() {
        _isPrinting = false;
        if (result.success) {
          _status = 'Print completed successfully';
          _addLog('Print operation successful', 'SUCCESS');
        } else {
          _status = 'Print failed: ${result.error?.message ?? "Unknown error"}';
          _addLog('Print operation failed: ${result.error?.message}', 'ERROR');
        }
      });
    }
  }

  void _addLog(String message, String level) {
    final log = SimpleLogEntry(
      message: message,
      level: level,
      timestamp: DateTime.now(),
    );

    setState(() {
      _logs.insert(0, log);
      if (_logs.length > 50) {
        _logs.removeLast();
      }
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Simplified Printer Demo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            BTPrinterSelector(
              onDeviceSelected: _onDeviceSelected,
              onConnect: _onConnect,
              onDisconnect: _onDisconnect,
              selectedDevice: _selectedDevice,
              isConnected: _isConnected,
              status: _status,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Format:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SegmentedButton<PrintMode>(
                  segments: const [
                    ButtonSegment(value: PrintMode.cpcl, label: Text('CPCL')),
                    ButtonSegment(value: PrintMode.zpl, label: Text('ZPL')),
                    ButtonSegment(value: PrintMode.auto, label: Text('Auto')),
                  ],
                  selected: {_printMode},
                  onSelectionChanged: (value) =>
                      _onPrintModeChanged(value.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Label Data:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _labelController,
                maxLines: null,
                expands: true,
                contextMenuBuilder: null,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter label data here',
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: !_isPrinting ? _print : null,
              icon: _isPrinting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.print),
              label: Text(_isPrinting ? 'Printing...' : 'Print'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() => _isLoading = true);
                      _addLog('Starting manual print operation', 'INFO');

                      // Get the CPCL content
                      const cpclContent = '''! 0 200 200 210 1
TEXT 4 0 30 40 Hello World
FORM
PRINT
''';

                      Result<void> result;
                      try {
                        result = await Zebra.print(cpclContent);
                      } catch (e, stack) {
                        debugPrint('=== PRINT EXCEPTION ===');
                        debugPrint('Exception: $e');
                        debugPrint('Stack Trace:');
                        debugPrint(stack.toString());
                        debugPrint('=====================');

                        setState(() {
                          _isLoading = false;
                          _status = 'Print failed: $e';
                        });
                        _addLog('Print exception: $e', 'ERROR');
                        return;
                      }

                      if (result.success) {
                        _showMessage('Print sent successfully');
                        _addLog('Manual print successful', 'SUCCESS');
                      } else {
                        final errorMsg =
                            result.error?.message ?? 'Unknown error';
                        debugPrint('=== PRINT ERROR ===');
                        debugPrint('Error: $errorMsg');
                        debugPrint('Error Code: ${result.error?.code}');
                        debugPrint(
                            'Error Number: ${result.error?.errorNumber}');
                        if (result.error?.dartStackTrace != null) {
                          debugPrint('Stack Trace:');
                          debugPrint(result.error!.dartStackTrace.toString());
                        }
                        debugPrint('==================');
                        _showMessage(errorMsg, isError: true);
                        _addLog('Manual print failed: $errorMsg', 'ERROR');
                      }

                      setState(() => _isLoading = false);
                    },
              child: const Text('Manual Print'),
            ),
            
            // Log Widget
            const SizedBox(height: 8),
            SimpleLogWidget(
              logs: _logs,
              onClearLogs: () => setState(() => _logs.clear()),
              height: 150,
            ),
          ],
        ),
      ),
    );
  }
}
