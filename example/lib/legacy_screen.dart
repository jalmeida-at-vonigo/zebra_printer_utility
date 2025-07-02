import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zebrautil/zebra_util.dart';
import 'bt_printer_selector.dart';

class LegacyScreen extends StatefulWidget {
  const LegacyScreen({super.key});

  @override
  State<LegacyScreen> createState() => _LegacyScreenState();
}

class _LegacyScreenState extends State<LegacyScreen> {
  ZebraDevice? _selectedDevice;
  bool _isConnected = false;
  String _status = '';
  bool _isPrinting = false;
  bool _useZPL = true; // Toggle between ZPL and CPCL
  late TextEditingController _labelController;
  StreamSubscription<String>? _statusSubscription;
  StreamSubscription<ZebraDevice?>? _connectionSubscription;

  final String defaultZPL = """^XA
^LL500
^FO50,50^A0N,50,50^FDZebra Test Print^FS
^FO50,150^A0N,30,30^FDConnection Successful!^FS
^FO50,200^A0N,25,25^FDPrinter Connected^FS
^FO50,250^A0N,25,25^FDTime: ${DateTime.now()}^FS
^FO50,350^BY3^BCN,100,Y,N,N^FD123456789^FS
^XZ""";

  final String defaultCPCL = """! 0 200 200 400 1
TEXT 4 0 30 40 Hello World
TEXT 4 0 30 100 CPCL Test Print
TEXT 4 0 30 160 Connection Successful!
TEXT 4 0 30 220 Time: ${DateTime.now().toString()}
BARCODE 128 1 1 50 30 280 123456789
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

  void _onDisconnect() {
    if (mounted) {
      setState(() {
        _isConnected = false;
        _status = 'Disconnected';
      });
    }
  }

  void _onFormatChanged(bool useZPL) {
    if (mounted) {
      setState(() {
        _useZPL = useZPL;
        _labelController.text = useZPL ? defaultZPL : defaultCPCL;
      });
    }
  }

  Future<void> _print() async {
    if (!_isConnected || _selectedDevice == null) return;
    if (mounted) {
      setState(() => _isPrinting = true);
    }
    final format = _useZPL ? PrintFormat.ZPL : PrintFormat.CPCL;
    final success = await Zebra.print(_labelController.text, format: format);
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
              'Legacy API (ZPL/CPCL)',
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
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('ZPL')),
                    ButtonSegment(value: false, label: Text('CPCL')),
                  ],
                  selected: {_useZPL},
                  onSelectionChanged: (value) => _onFormatChanged(value.first),
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
