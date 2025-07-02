import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zebrautil/zebra_util.dart';
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

  final String defaultCPCL = """! 0 200 200 300 1
TEXT 7 1 420 91 Bedroom 2 test value
TEXT 7 1 90 190 Equalizer
TEXT 7 1 420 42 6/27/2025
TEXT 7 1 90 42 Test Jane
TEXT 4 0 90 91 104
CENTER
BARCODE 39 1 1 50 0 237 00170000010422
LEFT
TEXT 4 0 88 169 689
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
    _cpclController.dispose();
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
        _status = 'Disconnected';
      });
    }
  }

  Future<void> _print() async {
    if (!_isConnected || _selectedDevice == null) return;
    if (mounted) {
      setState(() => _isPrinting = true);
    }
    final result =
        await Zebra.print(_cpclController.text, format: PrintFormat.CPCL);
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
