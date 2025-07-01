import 'package:flutter/material.dart';
import 'package:zebrautil/zebra_device.dart';
import 'package:zebrautil/zebra_printer.dart';
import 'package:zebrautil/zebra_util.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FutureBuilder(
        future: ZebraUtil.getPrinterInstance(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          final printer = snapshot.data as ZebraPrinter;
          return PrinterTemplate(printer);
        },
      ),
    );
  }
}

class PrinterTemplate extends StatefulWidget {
  const PrinterTemplate(this.printer, {super.key});
  final ZebraPrinter printer;
  @override
  State<PrinterTemplate> createState() => _PrinterTemplateState();
}

class _PrinterTemplateState extends State<PrinterTemplate> {
  late ZebraPrinter zebraPrinter;
  late ZebraController controller;
  late TextEditingController zplController;
  String? connectionError;
  bool isConnecting = false;

  final String defaultZPL = """^XA
^FO50,50^A0N,50,50^FDZebra Test Print^FS
^FO50,150^A0N,30,30^FDConnection Successful!^FS
^FO50,200^A0N,25,25^FDPrinter Connected^FS
^FO50,250^A0N,25,25^FDTime: ${DateTime.now()}^FS
^FO50,350^BY3^BCN,100,Y,N,N^FD123456789^FS
^XZ""";

  @override
  void initState() {
    zebraPrinter = widget.printer;
    controller = zebraPrinter.controller;
    zplController = TextEditingController(text: defaultZPL);
    zebraPrinter.startScanning();
    super.initState();
  }
  
  @override
  void dispose() {
    zplController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              const Text("My Printers"),
              if (zebraPrinter.isScanning)
                const Text(
                  "Searching for printers...",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (zebraPrinter.isScanning) {
              zebraPrinter.stopScanning();
            } else {
              zebraPrinter.startScanning();
            }
            setState(() {});
          },
          child: Icon(
              zebraPrinter.isScanning ? Icons.stop_circle : Icons.play_circle),
        ),
        body: Column(
          children: [
            // Connection status
            if (controller.selectedAddress != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: controller.printers.any((p) =>
                        p.address == controller.selectedAddress &&
                        p.isConnected)
                    ? Colors.green.shade100
                    : Colors.orange.shade100,
                child: Row(
                  children: [
                    Icon(
                      controller.printers.any((p) =>
                              p.address == controller.selectedAddress &&
                              p.isConnected)
                          ? Icons.check_circle
                          : Icons.warning,
                      color: controller.printers.any((p) =>
                              p.address == controller.selectedAddress &&
                              p.isConnected)
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.printers.any((p) =>
                                p.address == controller.selectedAddress &&
                                p.isConnected)
                            ? 'Connected to: ${controller.selectedAddress}'
                            : isConnecting
                                ? 'Connecting to: ${controller.selectedAddress}...'
                                : 'Disconnected from: ${controller.selectedAddress}',
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
                      const Text('ZPL Template:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          zplController.text = defaultZPL;
                        },
                        child: const Text('Reset to Default'),
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
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(8),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: controller.printers.any((p) =>
                              p.address == controller.selectedAddress &&
                              p.isConnected)
                          ? () {
                              zebraPrinter.print(data: zplController.text);
                            }
                          : null,
                      icon: const Icon(Icons.print),
                      label: const Text('Print Label'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Printer list
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, child) {
                  final printers = controller.printers;
                  if (printers.isEmpty) {
                    return _getNotAvailablePage();
                  }
                  return _getListDevices(printers);
                },
              ),
            ),
          ],
        ));
  }

  Widget _getListDevices(List<ZebraDevice> printers) {
    return ListView.builder(
        itemBuilder: (BuildContext context, int index) {
          final printer = printers[index];
          final isSelected = controller.selectedAddress == printer.address;
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
                    await zebraPrinter.disconnect();
                  } else {
                    await zebraPrinter.connectToPrinter(printer.address);
                  }

                  if (zebraPrinter.isScanning) {
                    zebraPrinter.stopScanning();
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
            selected: isSelected,
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
