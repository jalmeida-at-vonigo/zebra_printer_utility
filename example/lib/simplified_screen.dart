import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';
import 'bt_printer_selector.dart';

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

  final String defaultZPL = """^XA
^LL250
^FO50,50^A0N,50,50^FDHello from Flutter!^FS
^FO50,100^BY2^BCN,100,Y,N,N^FD123456789^FS
^XZ""";

  final String defaultCPCL = """! 0 200 200 200 1
TEXT 4 0 30 40 Hello from Flutter!
BARCODE 128 1 1 50 30 100 123456789
FORM
PRINT
""";

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: defaultZPL);
    _statusSubscription = Zebra.status.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });
    _connectionSubscription = Zebra.connection.listen((device) {
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
    final result = await Zebra.connect(device.address);
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

    PrintFormat? format;
    if (_printMode == PrintMode.zpl) {
      format = PrintFormat.zpl;
    } else if (_printMode == PrintMode.cpcl) {
      format = PrintFormat.cpcl;
    }
    // For Auto mode, format is null (auto-detected)

    Result<void> result;

    if (_isConnected && _selectedDevice != null) {
      // Use autoPrint with the connected printer
      result = await Zebra.autoPrint(
        _labelController.text,
        address: _selectedDevice!.address,
        format: format,
        disconnectAfter: false,

      );
    } else {
      // Use autoPrint to discover and use any available printer
      result = await Zebra.autoPrint(
        _labelController.text,
        format: format,
      );
    }
    
    if (mounted) {
      setState(() {
        _isPrinting = false;
        if (!result.success) {
          _status = 'Print failed: ${result.error?.message ?? "Unknown error"}';
        }
      });
    }
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
                        print('=== PRINT EXCEPTION ===');
                        print('Exception: $e');
                        print('Stack Trace:');
                        print(stack);
                        print('=====================');
                        _showMessage('Print exception: $e', isError: true);
                        setState(() => _isLoading = false);
                        return;
                      }

                      if (result.success) {
                        _showMessage('Print sent successfully');
                      } else {
                        final errorMsg =
                            'Print failed: ${result.error?.message}';
                        print('=== PRINT ERROR ===');
                        print('Error: $errorMsg');
                        print('Error Code: ${result.error?.code}');
                        print('Error Number: ${result.error?.errorNumber}');
                        if (result.error?.dartStackTrace != null) {
                          print('Stack Trace:');
                          print(result.error!.dartStackTrace);
                        }
                        print('==================');
                        _showMessage(errorMsg, isError: true);
                      }

                      setState(() => _isLoading = false);
                    },
              child: const Text('Manual Print'),
            ),


          ],
        ),
      ),
    );
  }
}
