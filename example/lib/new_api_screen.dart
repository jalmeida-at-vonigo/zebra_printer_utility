import 'package:flutter/material.dart';
import 'package:zebrautil/zebra_util.dart';

class NewApiScreen extends StatefulWidget {
  const NewApiScreen({super.key});

  @override
  State<NewApiScreen> createState() => _NewApiScreenState();
}

class _NewApiScreenState extends State<NewApiScreen> {
  late TextEditingController zplController;
  List<ZebraDevice> printers = [];
  String? connectionError;
  bool isConnecting = false;
  bool isScanning = false;
  String statusMessage = '';
  bool useCPCL = true;

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
B 39 1 1 50 0 237 E 0017 00000104 22-8C65-3061B6596A49                    
BT OFF
LEFT 0
T 4 0 88 169 689
FORM
PRINT
""";

  final String defaultZPL = """^XA
^FO50,50^A0N,50,50^FDZebra Test Print^FS
^FO50,150^A0N,30,30^FDConnection Successful!^FS
^FO50,200^A0N,25,25^FDPrinter Connected^FS
^FO50,250^A0N,25,25^FDTime: ${DateTime.now()}^FS
^FO50,350^BY3^BCN,100,Y,N,N^FD123456789^FS
^XZ""";

  @override
  void initState() {
    super.initState();
    zplController = TextEditingController(text: defaultCPCL);
    _initializePlugin();
  }

  Future<void> _initializePlugin() async {
    // Ensure the plugin is initialized before listening to streams
    await Zebra.discoverPrinters(timeout: const Duration(milliseconds: 100));
    await Zebra.stopDiscovery();

    // Listen to status updates
    Zebra.status.listen((status) {
      if (mounted) {
        setState(() => statusMessage = status);
      }
    });

    // Listen to device updates
    Zebra.devices.listen((devices) {
      if (mounted) {
        setState(() => printers = devices);
      }
    });

    // Start scanning for printers
    _startScanning();
  }

  Future<void> _startScanning() async {
    setState(() => isScanning = true);
    await Zebra.discoverPrinters();
    setState(() => isScanning = false);
  }

  Future<ZebraDevice?> _selectPrinter() async {
    return await showDialog<ZebraDevice>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Printer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: printers.length,
              itemBuilder: (context, index) {
                final printer = printers[index];
                return ListTile(
                  leading: Icon(
                    printer.isWifi ? Icons.wifi : Icons.bluetooth,
                    color: printer.color,
                  ),
                  title: Text(printer.name),
                  subtitle: Text(printer.address),
                  onTap: () => Navigator.of(context).pop(printer),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    zplController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectedPrinter = Zebra.connectedPrinter;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (isScanning) {
            await Zebra.stopDiscovery();
            setState(() => isScanning = false);
          } else {
            _startScanning();
          }
        },
        child: Icon(isScanning ? Icons.stop_circle : Icons.play_circle),
      ),
      body: Column(
        children: [
          // Title section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                const Text(
                  'New API with Auto-Print',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isScanning)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Searching for printers...',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          // Connection status
          if (connectedPrinter != null || isConnecting)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: connectedPrinter != null
                  ? Colors.green.shade100
                  : Colors.orange.shade100,
              child: Row(
                children: [
                  Icon(
                    connectedPrinter != null
                        ? Icons.check_circle
                        : Icons.warning,
                    color:
                        connectedPrinter != null ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      connectedPrinter != null
                          ? 'Connected to: ${connectedPrinter.name}'
                          : isConnecting
                              ? 'Connecting...'
                              : 'Disconnected',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // ZPL Editor
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Format: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('ZPL')),
                            ButtonSegment(value: true, label: Text('CPCL')),
                          ],
                          selected: {useCPCL},
                          onSelectionChanged: (Set<bool> selection) {
                            setState(() {
                              useCPCL = selection.first;
                              zplController.text =
                                  useCPCL ? defaultCPCL : defaultZPL;
                            });
                          },
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        zplController.text = useCPCL ? defaultCPCL : defaultZPL;
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: zplController,
                    maxLines: null,
                    expands: true,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(8),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: connectedPrinter != null
                            ? () async {
                                await Zebra.print(
                                  zplController.text,
                                  format: useCPCL
                                      ? PrintFormat.CPCL
                                      : PrintFormat.ZPL,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.print),
                        label: const Text('Print'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          setState(() {
                            connectionError = null;
                          });

                          // If multiple printers, show selection dialog
                          if (printers.length > 1) {
                            final selected = await _selectPrinter();
                            if (selected != null) {
                              final success = await Zebra.autoPrint(
                                zplController.text,
                                address: selected.address,
                                format: useCPCL
                                    ? PrintFormat.CPCL
                                    : PrintFormat.ZPL,
                              );
                              if (!success && mounted) {
                                setState(() {
                                  connectionError = 'Auto-print failed';
                                });
                              }
                            }
                          } else {
                            // Single or no printer - let autoPrint handle it
                            final success = await Zebra.autoPrint(
                              zplController.text,
                              format:
                                  useCPCL ? PrintFormat.CPCL : PrintFormat.ZPL,
                            );
                            if (!success && mounted) {
                              setState(() {
                                connectionError = printers.isEmpty
                                    ? 'No printers found'
                                    : 'Auto-print failed';
                              });
                            }
                          }
                        },
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Auto Print'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(),

          // Error message
          if (connectionError != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      connectionError!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => connectionError = null);
                    },
                    color: Colors.red.shade700,
                  ),
                ],
              ),
            ),

          // Printer list
          Expanded(
            child: printers.isEmpty
                ? _getNotAvailablePage()
                : _getListDevices(printers),
          ),
        ],
      ),
    );
  }

  Widget _getListDevices(List<ZebraDevice> printers) {
    return ListView.builder(
        itemBuilder: (BuildContext context, int index) {
          final printer = printers[index];
          final isConnected = printer.isConnected;

          return ListTile(
            title: Text(printer.name),
            subtitle: Text(
              printer.status,
              style: TextStyle(color: printer.color),
            ),
            leading: Icon(
              printer.isWifi ? Icons.wifi : Icons.bluetooth,
              color: printer.color,
            ),
            trailing: IconButton(
              icon: Icon(
                isConnected ? Icons.link_off : Icons.link,
                color: printer.color,
              ),
              onPressed: () async {
                setState(() {
                  isConnecting = true;
                  connectionError = null;
                });

                try {
                  if (isConnected) {
                    await Zebra.disconnect();
                  } else {
                    final success = await Zebra.connect(printer.address);
                    if (!success) {
                      setState(() {
                        connectionError =
                            'Failed to connect to ${printer.name}';
                      });
                    }
                  }

                  if (isScanning) {
                    await Zebra.stopDiscovery();
                    setState(() => isScanning = false);
                  }
                } catch (e) {
                  setState(() {
                    connectionError = e.toString();
                  });
                } finally {
                  setState(() {
                    isConnecting = false;
                  });
                }
              },
            ),
            selected: isConnected,
            selectedTileColor: Colors.blue.shade50,
          );
        },
        itemCount: printers.length);
  }

  SizedBox _getNotAvailablePage() {
    return const SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Printers not found"),
        ],
      ),
    );
  }
}
