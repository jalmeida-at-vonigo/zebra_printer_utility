import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';

class SmartDiscoveryScreen extends StatefulWidget {
  const SmartDiscoveryScreen({super.key});

  @override
  State<SmartDiscoveryScreen> createState() => _SmartDiscoveryScreenState();
}

class _SmartDiscoveryScreenState extends State<SmartDiscoveryScreen> {
  final ZebraPrinterService _service = ZebraPrinterService();
  StreamSubscription<SmartDiscoveryResult>? _discoverySubscription;
  
  List<ZebraDevice> _printers = [];
  ZebraDevice? _selectedPrinter;
  ZebraDevice? _recommendedPrinter;
  bool _isDiscovering = false;
  String _status = '';
  
  @override
  void initState() {
    super.initState();
    _initializeService();
  }
  
  Future<void> _initializeService() async {
    try {
      await _service.initialize();
      setState(() {
        _status = 'Service initialized';
      });
    } catch (e) {
      setState(() {
        _status = 'Initialization error: $e';
      });
    }
  }
  
  Future<void> _startSmartDiscovery() async {
    setState(() {
      _isDiscovering = true;
      _printers.clear();
      _selectedPrinter = null;
      _recommendedPrinter = null;
      _status = 'Starting smart discovery...';
    });
    
    _discoverySubscription?.cancel();
    _discoverySubscription = _service.smartDiscoveryStream(
      timeout: const Duration(seconds: 10),
      preferWiFi: true,
      previouslySelected: _selectedPrinter,
    ).listen(
      (result) {
        setState(() {
          _printers = result.sortedPrinters;
          _recommendedPrinter = result.selectedPrinter;
          
          if (result.isComplete) {
            _isDiscovering = false;
            _status = 'Discovery complete. Found ${_printers.length} printer(s)';
          } else {
            _status = 'Discovering... Found ${_printers.length} printer(s)';
          }
        });
      },
      onError: (error) {
        setState(() {
          _isDiscovering = false;
          _status = 'Discovery error: $error';
        });
      },
    );
  }
  
  Future<void> _connectToPrinter(ZebraDevice printer) async {
    setState(() {
      _selectedPrinter = printer;
      _status = 'Connecting to ${printer.name}...';
    });
    final result = await _service.connect(printer);
    setState(() {
      if (result.success) {
        _status = 'Connected to ${printer.name}';
      } else {
        _status = 'Connection failed: ${result.error?.message}';
      }
    });
  }

  Future<void> _printTest() async {
    final printer = _selectedPrinter;
    if (printer == null) {
      setState(() {
        _status = 'No printer selected';
      });
      return;
    }
    // Connect if not already connected
    if (_service.connectedPrinter?.address != printer.address) {
      await _connectToPrinter(printer);
      if (_service.connectedPrinter?.address != printer.address) {
        setState(() {
          _status = 'Failed to connect to selected printer';
        });
        return;
      }
    }
    setState(() {
      _status = 'Printing test label...';
    });
    final connectedPrinter = _service.connectedPrinter;
    final connectedPrinterName =
        connectedPrinter?.displayName ?? connectedPrinter?.name ?? 'Unknown';
    final connectedPrinterModel = connectedPrinter?.model ?? '';
    final connectedPrinterInfo = connectedPrinterModel.isNotEmpty
        ? '$connectedPrinterName ($connectedPrinterModel)'
        : connectedPrinterName;
    final testData = '''
^XA
^FO50,50
^ADN,36,20
^FDSmart Discovery Test
^FS
^FO50,100
^ADN,36,20
^FDPrinter: $connectedPrinterInfo
^FS
^XZ
''';
    final result = await _service.print(testData);
    setState(() {
      if (result.success) {
        _status = 'Print successful';
      } else {
        _status = 'Print failed: ${result.error?.message}';
      }
    });
  }
  
  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _service.disconnect();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Discovery Demo'),
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Text(
              _status,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isDiscovering ? null : _startSmartDiscovery,
                  icon: _isDiscovering 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isDiscovering ? 'Discovering...' : 'Smart Discovery'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _service.connectedPrinter != null ? _printTest : null,
                  icon: const Icon(Icons.print),
                  label: const Text('Print Test'),
                ),
              ],
            ),
          ),
          
          // Printer list
          Expanded(
            child: Column(
              children: [
                if (_selectedPrinter != null) ...[
                  Card(
                    color: Colors.blue[50],
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedPrinter!.displayName ??
                                _selectedPrinter!.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(_selectedPrinter!.address,
                              style: const TextStyle(fontSize: 13)),
                          if (_selectedPrinter!.brand != null ||
                              _selectedPrinter!.model != null)
                            Text(
                                '${_selectedPrinter!.brand ?? ''} ${_selectedPrinter!.model ?? ''}'
                                    .trim(),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          if (_selectedPrinter!.manufacturer != null)
                            Text(
                                'Manufacturer: ${_selectedPrinter!.manufacturer}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          if (_selectedPrinter!.firmwareRevision != null)
                            Text(
                                'Firmware: ${_selectedPrinter!.firmwareRevision}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          if (_selectedPrinter!.hardwareRevision != null)
                            Text(
                                'Hardware: ${_selectedPrinter!.hardwareRevision}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          if (_selectedPrinter!.connectionType != null)
                            Text(
                                'Connection: ${_selectedPrinter!.connectionType}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _printers.length,
                    itemBuilder: (context, index) {
                      final printer = _printers[index];
                      final isRecommended =
                          printer.address == _recommendedPrinter?.address;
                      final isSelected =
                          printer.address == _selectedPrinter?.address;
                      final isConnected =
                          printer.address == _service.connectedPrinter?.address;
                      return Card(
                        color: isConnected
                            ? Colors.green[50]
                            : isSelected
                                ? Colors.blue[100]
                                : null,
                        child: ListTile(
                          leading: Icon(
                            Icons.print,
                            color: isConnected
                                ? Colors.green
                                : isRecommended
                                    ? Colors.orange
                                    : null,
                          ),
                          title: Text(printer.displayName ?? printer.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(printer.address),
                              if (printer.brand != null ||
                                  printer.model != null)
                                Text(
                                    '${printer.brand ?? ''} ${printer.model ?? ''}'
                                        .trim(),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              if (printer.manufacturer != null)
                                Text('Manufacturer: ${printer.manufacturer}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              if (printer.firmwareRevision != null)
                                Text('Firmware: ${printer.firmwareRevision}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              if (printer.hardwareRevision != null)
                                Text('Hardware: ${printer.hardwareRevision}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              if (printer.connectionType != null)
                                Text('Connection: ${printer.connectionType}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Chip(
                                    label:
                                        Text(printer.isWifi ? 'WiFi' : 'BLE'),
                                    backgroundColor: printer.isWifi
                                        ? Colors.blue[100]
                                        : Colors.purple[100],
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  if (isRecommended) ...[
                                    const SizedBox(width: 4),
                                    Chip(
                                      label: const Text('Recommended'),
                                      backgroundColor: Colors.orange[100],
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ],
                                  if (isConnected) ...[
                                    const SizedBox(width: 4),
                                    Chip(
                                      label: const Text('Connected'),
                                      backgroundColor: Colors.green[100],
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: Colors.blue)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedPrinter = printer;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 