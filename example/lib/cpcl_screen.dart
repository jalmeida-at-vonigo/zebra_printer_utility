import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';
import 'bt_printer_selector.dart';

class CPCLScreen extends StatefulWidget {
  const CPCLScreen({super.key});

  @override
  State<CPCLScreen> createState() => _CPCLScreenState();
}

class _CPCLScreenState extends State<CPCLScreen> {
  ZebraDevice? _selectedDevice;
  bool _isConnected = false;
  String _status = 'Not connected';
  bool _isPrinting = false;
  late TextEditingController _cpclController;
  StreamSubscription<String>? _statusSubscription;
  StreamSubscription<ZebraDevice?>? _connectionSubscription;
  bool _useSimpleExample = false;

  final String defaultCPCL = """! 0 200 200 400 1
ON-FEED IGNORE
LABEL
CONTRAST 0
TONE 0
SPEED 5
PAGE-WIDTH 800
BAR-SENSE
PCX 11 8 !<PRISMLOGO.png
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

  final String simpleCPCL = """! 0 200 200 210 1
TEXT 4 0 30 40 Hello from Flutter!
TEXT 4 0 30 100 Test Label
TEXT 4 0 30 160 CPCL Mode
FORM
PRINT
""";

  final String compactCPCL = """! 0 200 200 100 1
TEXT 4 0 10 10 Test Print
TEXT 4 0 10 40 ${DateTime.now().toString().substring(0, 16)}
FORM
PRINT
""";

  @override
  void initState() {
    super.initState();
    _cpclController = TextEditingController(text: simpleCPCL);
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
    _cpclController.dispose();
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
        _status = 'Disconnected';
      });
    }
  }

  Future<void> _print() async {
    if (!_isConnected || _selectedDevice == null) return;
    if (mounted) {
      setState(() => _isPrinting = true);
    }
    //final result =
    //    await Zebra.printCPCLDirect(_cpclController.text);
    final result =
        await Zebra.print(_cpclController.text, format: PrintFormat.cpcl);
    if (mounted) {
      setState(() {
        _isPrinting = false;
        if (!result.success) {
          _status = 'Print failed: ${result.error?.message ?? "Unknown error"}';
        }
      });
    }
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
              'CPCL Print (Bluetooth)',
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
                const Text('CPCL Data:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _useSimpleExample = !_useSimpleExample;
                      _cpclController.text =
                          _useSimpleExample ? defaultCPCL : simpleCPCL;
                    });
                  },
                  child: Text(_useSimpleExample
                      ? 'Use Simple Example'
                      : 'Use Complex Example'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _cpclController,
                maxLines: null,
                expands: true,
                contextMenuBuilder: null,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter CPCL commands here',
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isConnected && !_isPrinting ? _print : null,
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
          ],
        ),
      ),
    );
  }
}
