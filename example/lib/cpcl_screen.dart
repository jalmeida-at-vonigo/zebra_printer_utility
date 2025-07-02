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

  final String defaultCPCL = """! 0 200 200 210 1
TEXT 0 0 10 10 Hello World
PRINT
""";

  @override
  void initState() {
    super.initState();
    _cpclController = TextEditingController(text: defaultCPCL);
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
    final connected = await Zebra.connect(device.address);
    if (mounted) {
      setState(() {
        _isConnected = connected;
        _selectedDevice = device;
        _status =
            connected ? 'Connected to ${device.name}' : 'Failed to connect';
      });
    }
  }

  Future<void> _print() async {
    if (!_isConnected || _selectedDevice == null) return;
    if (mounted) {
      setState(() => _isPrinting = true);
    }
    final success =
        await Zebra.print(_cpclController.text, format: PrintFormat.CPCL);
    if (mounted) {
      setState(() {
        _isPrinting = false;
        if (!success) _status = 'Print failed';
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
              selectedDevice: _selectedDevice,
              isConnected: _isConnected,
              status: _status,
            ),
            const SizedBox(height: 16),
            const Text('CPCL Data:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _cpclController,
                maxLines: null,
                expands: true,
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
