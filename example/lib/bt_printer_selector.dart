import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';

class BTPrinterSelector extends StatefulWidget {
  final Function(ZebraDevice) onDeviceSelected;
  final Future<void> Function(ZebraDevice) onConnect;
  final VoidCallback? onDisconnect;
  final ZebraDevice? selectedDevice;
  final bool isConnected;
  final String status;

  const BTPrinterSelector({
    super.key,
    required this.onDeviceSelected,
    required this.onConnect,
    this.onDisconnect,
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
  StreamSubscription<List<ZebraDevice>>? _discoverySubscription;
  bool _isDisconnecting = false;
  String? _connectingAddress;
  final Set<String> _discoveredAddresses = {};

  // Manual entry state
  bool _manualEntryMode = false;
  final _manualIpController = TextEditingController();
  final _manualNameController = TextEditingController();
  String? _manualError;

  @override
  void initState() {
    super.initState();
    _initPrinterState();
  }

  Future<void> _initPrinterState() async {
    final statusResult = await Zebra.status;
    if (statusResult.success) {
      _statusSubscription = statusResult.data!.listen((status) {
        if (mounted) {
          setState(() => _status = status);
        }
      });
    }
    _discover();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _discoverySubscription?.cancel();
    _manualIpController.dispose();
    _manualNameController.dispose();
    super.dispose();
  }

  Future<void> _discover() async {
    if (!mounted) return;

    setState(() {
      _isScanning = true;
      _printers = [];
      _discoveredAddresses.clear();
    });

    try {
      // Use the new streaming discovery API
      final discoveryStream = Zebra.discovery.discoverPrintersStream(
        timeout: const Duration(seconds: 10),
        includeWifi: true,
        includeBluetooth: true,
      );

      _discoverySubscription = discoveryStream.listen(
        (printers) {
          if (!mounted) return;

          // Filter out duplicates and add new printers
          final newPrinters = <ZebraDevice>[];
          for (final printer in printers) {
            if (!_discoveredAddresses.contains(printer.address)) {
              _discoveredAddresses.add(printer.address);
              newPrinters.add(printer);
            }
          }

          if (newPrinters.isNotEmpty) {
            setState(() {
              _printers.addAll(newPrinters);
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _status = 'Discovery error: $error';
              _isScanning = false;
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isScanning = false;
              if (_printers.isEmpty) {
                _status = 'No printers found';
              } else {
                _status = 'Found ${_printers.length} printer(s)';
              }
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Discovery error: $e';
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _stopDiscovery() async {
    _discoverySubscription?.cancel();
    await Zebra.stopDiscovery();
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
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
                _connectingAddress != null
                    ? 'Connecting...'
                    : isConnected && selected != null
                        ? 'Connected:  [1m${selected.name}\u001b[0m'
                        : _status.isNotEmpty
                            ? _status
                            : 'Not connected',
                style: TextStyle(
                  color: _connectingAddress != null
                      ? Colors.blue
                      : isConnected
                          ? Colors.green
                          : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isConnected && selected != null) ...[
              IconButton(
                icon: _isDisconnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_off),
                onPressed: _isDisconnecting
                    ? null
                    : () async {
                        setState(() {
                          _isDisconnecting = true;
                          _status = 'Disconnecting...';
                        });
                        await Zebra.disconnect();
                        if (mounted) {
                          setState(() {
                            _isDisconnecting = false;
                            _status = 'Disconnected';
                          });
                        }
                        widget.onDisconnect?.call();
                      },
                tooltip: 'Disconnect',
              ),
              const SizedBox(width: 8),
            ],
            if (_isScanning) ...[
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _stopDiscovery,
                tooltip: 'Stop Discovery',
              ),
              const SizedBox(width: 8),
            ],
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
        // Toggle for discovery/manual entry
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _manualEntryMode = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      !_manualEntryMode ? Colors.blue : Colors.grey[200],
                  foregroundColor:
                      !_manualEntryMode ? Colors.white : Colors.black,
                ),
                child: const Text('Discovered Printers'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _manualEntryMode = true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _manualEntryMode ? Colors.blue : Colors.grey[200],
                  foregroundColor:
                      _manualEntryMode ? Colors.white : Colors.black,
                ),
                child: const Text('Manual Entry'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_manualEntryMode)
          _buildManualEntry(context, isConnected, selected)
        else
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
                            ? (isConnected
                                ? Colors.green[100]
                                : Colors.blue[50])
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
                                    onPressed: isConnected && isSelected ||
                                            _connectingAddress != null
                                        ? null
                                        : () async {
                                            setState(() {
                                              _connectingAddress =
                                                  printer.address;
                                            });
                                            try {
                                              await widget.onConnect(printer);
                                            } finally {
                                              if (mounted) {
                                                setState(() {
                                                  _connectingAddress = null;
                                                });
                                              }
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                    child: _connectingAddress == printer.address
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(isConnected && isSelected
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

  Widget _buildManualEntry(
      BuildContext context, bool isConnected, ZebraDevice? selected) {
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _manualIpController,
              decoration: InputDecoration(
                labelText: 'Printer IP Address',
                hintText: 'e.g. 192.168.1.100',
                errorText: _manualError,
              ),
              keyboardType: TextInputType.url,
              autofillHints: const [AutofillHints.url],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _manualNameController,
              decoration: const InputDecoration(
                labelText: 'Printer Name (optional)',
                hintText: 'e.g. Custom Zebra',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: () async {
                  final ip = _manualIpController.text.trim();
                  if (ip.isEmpty || !_validateIp(ip)) {
                    setState(() => _manualError = 'Enter a valid IP address');
                    return;
                  }
                  setState(() => _manualError = null);
                  final device = ZebraDevice(
                    address: ip,
                    name: _manualNameController.text.trim().isNotEmpty
                        ? _manualNameController.text.trim()
                        : 'Custom Printer ($ip)',
                    isWifi: true,
                    status: 'Manual',
                    brand: 'Zebra',
                    model: null,
                    displayName: null,
                    manufacturer: null,
                    firmwareRevision: null,
                    hardwareRevision: null,
                    connectionType: 'manual',
                    isBluetooth: false,
                  );
                  widget.onDeviceSelected(device);
                  setState(() {
                    _connectingAddress = ip;
                  });
                  try {
                    await widget.onConnect(device);
                  } finally {
                    if (mounted) {
                      setState(() {
                        _connectingAddress = null;
                      });
                    }
                  }
                },
                child: _connectingAddress == _manualIpController.text.trim()
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Connect'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _validateIp(String ip) {
    final regex = RegExp(r'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$');
    if (!regex.hasMatch(ip)) return false;
    return ip.split('.').every((octet) {
      final n = int.tryParse(octet);
      return n != null && n >= 0 && n <= 255;
    });
  }
}
