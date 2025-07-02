import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zebrautil/zebra_util.dart';

class BTPrinterSelector extends StatefulWidget {
  final Function(ZebraDevice) onDeviceSelected;
  final Function(ZebraDevice) onConnect;
  final ZebraDevice? selectedDevice;
  final bool isConnected;
  final String status;

  const BTPrinterSelector({
    super.key,
    required this.onDeviceSelected,
    required this.onConnect,
    this.selectedDevice,
    this.isConnected = false,
    this.status = '',
  });

  @override
  State<BTPrinterSelector> createState() => _BTPrinterSelectorState();
}

class _BTPrinterSelectorState extends State<BTPrinterSelector> {
  List<ZebraDevice> _printers = [];
  bool _isScanning = false;
  String _status = '';
  StreamSubscription<String>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _statusSubscription = Zebra.status.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });
    _discover();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _discover() async {
    if (!mounted) return;

    setState(() {
      _isScanning = true;
      _printers = [];
    });

    try {
      final printers = await Zebra.discoverPrinters();
      if (mounted) {
        setState(() {
          _printers = printers;
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Discovery error: $e';
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.isConnected;
    final selected = widget.selectedDevice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isConnected && selected != null
                    ? 'Connected: ${selected.name}'
                    : _status.isNotEmpty
                        ? _status
                        : 'Not connected',
                style: TextStyle(
                  color: isConnected ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: _isScanning ? null : _discover,
              tooltip: 'Discover Printers',
            ),
          ],
        ),
        const SizedBox(height: 8),
        _printers.isEmpty
            ? const Text('No printers found.')
            : SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _printers.length,
                  itemBuilder: (context, index) {
                    final printer = _printers[index];
                    final isSelected = selected?.address == printer.address;
                    return Card(
                      color: isSelected
                          ? (isConnected ? Colors.green[100] : Colors.blue[50])
                          : null,
                      child: InkWell(
                        onTap: () => widget.onDeviceSelected(printer),
                        child: Container(
                          width: 180,
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    printer.isWifi
                                        ? Icons.wifi
                                        : Icons.bluetooth,
                                    color: printer.color,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      printer.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                printer.address,
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                height: 32,
                                child: ElevatedButton(
                                  onPressed: isConnected && isSelected
                                      ? null
                                      : () => widget.onConnect(printer),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                  child: Text(isConnected && isSelected
                                      ? 'Connected'
                                      : 'Connect'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }
}
