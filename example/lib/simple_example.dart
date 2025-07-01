import 'package:flutter/material.dart';
import 'package:zebrautil/zebra_util.dart';

/// Simple example of using the Zebra printer plugin
void main() => runApp(const SimpleExample());

class SimpleExample extends StatefulWidget {
  const SimpleExample({Key? key}) : super(key: key);

  @override
  State<SimpleExample> createState() => _SimpleExampleState();
}

class _SimpleExampleState extends State<SimpleExample> {
  String _status = 'Not connected';
  List<ZebraDevice> _printers = [];
  bool _isScanning = false;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    // Listen to status updates
    Zebra.status.listen((status) {
      setState(() => _status = status);
    });
  }

  Future<void> _discover() async {
    setState(() => _isScanning = true);

    try {
      final printers = await Zebra.discoverPrinters();
      setState(() {
        _printers = printers;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Discovery error: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _connect(String address) async {
    final connected = await Zebra.connect(address);
    if (!connected) {
      setState(() => _status = 'Failed to connect');
    }
  }

  Future<void> _print() async {
    setState(() => _isPrinting = true);

    // Simple ZPL to print "Hello World"
    const zpl = '''
^XA
^FO50,50
^ADN,36,20
^FDHello from Flutter!
^FS
^FO50,100
^BY2
^BCN,100,Y,N,N
^FD123456789
^FS
^XZ
''';

    final success = await Zebra.print(zpl);

    setState(() {
      _isPrinting = false;
      if (!success) {
        _status = 'Print failed';
      }
    });
  }

  Future<void> _disconnect() async {
    await Zebra.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = Zebra.connectedPrinter != null;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Zebra Printer Example'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status
              Card(
                color: isConnected ? Colors.green[50] : Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        isConnected ? Icons.check_circle : Icons.info,
                        color: isConnected ? Colors.green : Colors.orange,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _status,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (isConnected) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Connected to: ${Zebra.connectedPrinter!.name}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isScanning ? null : _discover,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isScanning ? 'Scanning...' : 'Discover'),
                  ),
                  if (isConnected) ...[
                    ElevatedButton.icon(
                      onPressed: _isPrinting ? null : _print,
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print),
                      label: Text(_isPrinting ? 'Printing...' : 'Print Test'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Zebra.calibrate(),
                      icon: const Icon(Icons.tune),
                      label: const Text('Calibrate'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _disconnect,
                      icon: const Icon(Icons.close),
                      label: const Text('Disconnect'),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // Printer list
              Expanded(
                child: _printers.isEmpty
                    ? Center(
                        child: Text(
                          'No printers found\nTap Discover to search',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _printers.length,
                        itemBuilder: (context, index) {
                          final printer = _printers[index];
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                printer.isWifi ? Icons.wifi : Icons.bluetooth,
                                color: printer.isConnected
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              title: Text(printer.name),
                              subtitle: Text(printer.address),
                              trailing: printer.isConnected
                                  ? const Chip(
                                      label: Text('Connected'),
                                      backgroundColor: Colors.green,
                                      labelStyle:
                                          TextStyle(color: Colors.white),
                                    )
                                  : ElevatedButton(
                                      onPressed: () =>
                                          _connect(printer.address),
                                      child: const Text('Connect'),
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
