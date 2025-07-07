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
  
  @override
  void initState() {
    super.initState();
    _initializeService();
  }
  
  Future<void> _initializeService() async {
    try {
      await _service.initialize();
    } catch (e) {
      // setState(() {
      //   _status = 'Initialization error: $e';
      // });
    }
  }
  
  Future<void> _startSmartDiscovery() async {
    setState(() {
      _isDiscovering = true;
      _printers.clear();
      _selectedPrinter = null;
      _recommendedPrinter = null;
      // _status = 'Starting smart discovery...';
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
            // _status = 'Discovery complete. Found ${_printers.length} printer(s)';
          } else {
            // _status = 'Discovering... Found ${_printers.length} printer(s)';
          }
        });
      },
      onError: (error) {
        setState(() {
          _isDiscovering = false;
          // _status = 'Discovery error: $error';
        });
      },
    );
  }
  
  Future<void> _showPrintPopup() async {
    const testData = '''
^XA
^FO50,50
^ADN,36,20
^FDSmart Discovery Test
^FS
^FO50,100
^ADN,36,20
^FDPrinter Selection Demo
^FS
^XZ
''';
    
    final result = await showDialog<ZebraDevice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ExamplePrintingPopup(
        printData: testData,
        previouslySelected: _selectedPrinter,
        onPrinterSelected: (printer) {
          setState(() {
            _selectedPrinter = printer;
          });
        },
        onCancel: () {
          // User cancelled
        },
      ),
    );

    if (result != null) {
      setState(() {
        _selectedPrinter = result;
        // _status = 'Print completed successfully with ${result.name}';
      });
    }
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
            child: const Text(
              // _status,
              'Service initialized',
              style: TextStyle(fontWeight: FontWeight.bold),
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
                  onPressed: _printers.isNotEmpty ? _showPrintPopup : null,
                  icon: const Icon(Icons.print),
                  label: const Text('Print with Popup'),
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

/// Simplified printing popup for examples
class _ExamplePrintingPopup extends StatefulWidget {
  final String printData;
  final ZebraDevice? previouslySelected;
  final Function(ZebraDevice) onPrinterSelected;
  final VoidCallback onCancel;

  const _ExamplePrintingPopup({
    required this.printData,
    this.previouslySelected,
    required this.onPrinterSelected,
    required this.onCancel,
  });

  @override
  State<_ExamplePrintingPopup> createState() => _ExamplePrintingPopupState();
}

class _ExamplePrintingPopupState extends State<_ExamplePrintingPopup>
    with TickerProviderStateMixin {
  StreamSubscription<List<ZebraDevice>>? _discoverySubscription;
  List<ZebraDevice> _printers = [];
  ZebraDevice? _selectedPrinter;
  bool _isDiscovering = false;
  bool _isPrinting = false;
  bool _printSuccess = false;
  bool _printFailed = false;
  String _printStatus = '';

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // Manual entry state
  bool _manualEntryMode = false;
  bool _manualEntryCompleted = false;
  final _manualIpController = TextEditingController();
  final _manualNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedPrinter = widget.previouslySelected;

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    // Start animations immediately
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();

    _startDiscovery();
  }

  void _startDiscovery() {
    setState(() {
      _isDiscovering = true;
      _printStatus = 'Discovering printers...';
    });

    _discoverySubscription = Zebra.discovery
        .discoverPrintersStream(
      timeout: const Duration(seconds: 10),
      includeWifi: true,
      includeBluetooth: true,
    )
        .listen(
      (printers) {
        if (mounted) {
          setState(() {
            _printers = printers;
            if (_selectedPrinter == null && printers.isNotEmpty) {
              _selectedPrinter = printers.first;
            }
            _printStatus = 'Found ${_printers.length} printers';
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isDiscovering = false;
            _printStatus = 'Discovery error: $error';
          });
        }
      },
    );
  }

  Future<void> _stopDiscovery() async {
    _discoverySubscription?.cancel();
    await Zebra.stopDiscovery();
    if (mounted) {
      setState(() {
        _isDiscovering = false;
        _printStatus = 'Discovery stopped. Found ${_printers.length} printers.';
      });
    }
  }

  Future<void> _closePopup() async {
    await _stopDiscovery();
    _discoverySubscription?.cancel();
    if (mounted) {
      Navigator.of(context).pop();
      widget.onCancel();
    }
  }

  Future<void> _cancelPrinting() async {
    setState(() {
      _isPrinting = false;
      _printStatus = 'Printing cancelled';
      _printSuccess = false;
      _printFailed = false;
    });

    await _stopDiscovery();
    _discoverySubscription?.cancel();

    if (mounted) {
      Navigator.of(context).pop();
      widget.onCancel();
    }
  }

  Future<void> _printToPrinter(ZebraDevice printer) async {
    await _stopDiscovery();
    final printerDisplayName = _getCleanPrinterName(printer);
    setState(() {
      _isPrinting = true;
      _printStatus = 'Connecting to $printerDisplayName...';
      _printSuccess = false;
      _printFailed = false;
    });

    try {
      Result<void> connectResult;
      int retryCount = 0;
      const maxRetries = 2;
      do {
        if (retryCount > 0) {
          setState(() {
            _printStatus = 'Retrying connection... (attempt ${retryCount + 1})';
          });
          await Future.delayed(const Duration(milliseconds: 500));
        }
        connectResult = await Zebra.connect(printer.address);
        retryCount++;
      } while (!connectResult.success && retryCount <= maxRetries);

      if (!connectResult.success) {
        setState(() {
          _isPrinting = false;
          _printFailed = true;
          _printStatus =
              'Connection failed after $maxRetries attempts: ${connectResult.error?.message}';
        });
        return;
      }

      setState(() {
        _printStatus = 'Connected. Sending print data...';
      });
      await Future.delayed(const Duration(milliseconds: 250));

      final printResult = await Zebra.print(widget.printData);
      if (printResult.success) {
        setState(() {
          _isPrinting = false;
          _printSuccess = true;
          _printStatus = 'Print completed successfully!';
        });
        if (widget.previouslySelected?.address != printer.address) {
          widget.onPrinterSelected(printer);
        }
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop(printer);
        }
      } else {
        setState(() {
          _isPrinting = false;
          _printFailed = true;
          _printStatus = 'Print failed: ${printResult.error?.message}';
        });
      }
    } catch (e) {
      setState(() {
        _isPrinting = false;
        _printFailed = true;
        _printStatus = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    Zebra.stopDiscovery();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _manualIpController.dispose();
    _manualNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  if (!_isPrinting) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() => _manualEntryMode = false);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: !_manualEntryMode
                                    ? Colors.blue
                                    : Colors.grey[200],
                                foregroundColor: !_manualEntryMode
                                    ? Colors.white
                                    : Colors.black,
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
                                backgroundColor: _manualEntryMode
                                    ? Colors.blue
                                    : Colors.grey[200],
                                foregroundColor: _manualEntryMode
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              child: const Text('Manual Entry'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_isPrinting || _printStatus.isNotEmpty)
                    _buildStatusPanel(),
                  Flexible(
                    child: _isPrinting
                        ? _buildPrintingView()
                        : _buildUnifiedPrinterListView(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blue, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.print,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Printer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap any printer to print',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (_isDiscovering && !_isPrinting)
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.white, size: 24),
              onPressed: _stopDiscovery,
              tooltip: 'Stop Discovery',
            ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: _isPrinting ? _cancelPrinting : _closePopup,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel() {
    Color statusColor;
    IconData statusIcon;

    if (_printSuccess) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (_printFailed) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else {
      statusColor = Colors.blue;
      statusIcon = Icons.print;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withAlpha(76),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _printStatus,
              style: TextStyle(
                color: statusColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrintingView() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated printer icon
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _printSuccess
                        ? Colors.green.withAlpha(25)
                        : _printFailed
                            ? Colors.red.withAlpha(25)
                            : Colors.blue.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _printSuccess
                        ? Icons.check_circle
                        : _printFailed
                            ? Icons.error
                            : Icons.print,
                    color: _printSuccess
                        ? Colors.green
                        : _printFailed
                            ? Colors.red
                            : Colors.blue,
                    size: 48,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Animated progress indicator
          if (!_printSuccess && !_printFailed)
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1500),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    value: _printSuccess ? 1.0 : null,
                    valueColor: AlwaysStoppedAnimation<Color>(_printSuccess
                        ? Colors.green
                        : _printFailed
                            ? Colors.red
                            : Colors.blue),
                    backgroundColor: Colors.grey.withAlpha(51),
                    minHeight: 6,
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          // Status text
          Text(
            _printStatus,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedPrinterListView() {
    if (_manualEntryMode) {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            // Manual entry section
            if (!_manualEntryCompleted) _buildManualEntryForm(),
            if (_manualEntryCompleted) _buildManualEntryCard(),

            // Discovery section below manual entry
            const SizedBox(height: 24),
            _buildDiscoverySection(),
          ],
        ),
      );
    } else {
      return _buildDiscoverySection();
    }
  }

  Widget _buildManualEntryForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _manualIpController,
            decoration: const InputDecoration(
              labelText: 'Printer IP Address',
              hintText: 'e.g. 192.168.1.100',
            ),
            keyboardType: TextInputType.url,
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
                  return;
                }

                // Create manual printer device
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

                // Add to printers list and mark as completed
                setState(() {
                  _printers.add(device);
                  _selectedPrinter = device;
                  _manualEntryCompleted = true;
                });
              },
              child: const Text('Add Printer'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntryCard() {
    final ip = _manualIpController.text.trim();
    final name = _manualNameController.text.trim();

    return Container(
      margin: const EdgeInsets.all(16),
      child: _buildPrinterCard(
        ZebraDevice(
          address: ip,
          name: name.isNotEmpty ? name : 'Custom Printer ($ip)',
          isWifi: true,
          status: 'Manual',
          brand: 'Zebra',
          model: 'Manual Entry',
          displayName: null,
          manufacturer: null,
          firmwareRevision: null,
          hardwareRevision: null,
          connectionType: 'manual',
          isBluetooth: false,
        ),
        prominent: true,
      ),
    );
  }

  Widget _buildDiscoverySection() {
    if (_isDiscovering && _printers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text(
              'Discovering printers...',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep this window open to find more printers',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!_isDiscovering && _printers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.print_disabled,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No printers found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure your printers are turned on and nearby',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startDiscovery,
              child: const Text('Retry Discovery'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_isDiscovering)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.blue.withAlpha(76), width: 1),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Discovery active - Found ${_printers.length} printers',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _stopDiscovery,
                    child: const Text('Stop'),
                  ),
                ],
              ),
            ),

          // Show printers in a grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _printers.length,
            itemBuilder: (context, index) {
              final printer = _printers[index];
              return _buildPrinterCard(printer, prominent: false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterCard(ZebraDevice printer, {bool prominent = false}) {
    IconData connIcon;
    String? connInfo;
    Color connColor;

    if (printer.isWifi == true) {
      connIcon = Icons.wifi;
      connInfo = printer.address;
      connColor = Colors.blue;
    } else if (printer.isBluetooth == true) {
      connIcon = Icons.bluetooth;
      connInfo = null;
      connColor = Colors.purple;
    } else {
      connIcon = Icons.usb;
      connInfo = printer.connectionType ?? 'Unknown';
      connColor = Colors.grey;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _printToPrinter(printer),
        borderRadius: BorderRadius.circular(prominent ? 16 : 10),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: prominent ? 0 : 4),
          padding: EdgeInsets.symmetric(
            horizontal: prominent ? 20 : 10,
            vertical: prominent ? 20 : 8,
          ),
          decoration: BoxDecoration(
            color: prominent ? Colors.blue.withAlpha(25) : Colors.white,
            borderRadius: BorderRadius.circular(prominent ? 16 : 10),
            border: Border.all(
              color:
                  prominent ? Colors.blue.withAlpha(76) : Colors.grey[300]!,
              width: prominent ? 2 : 1,
            ),
            boxShadow: [
              if (!prominent)
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(prominent ? 12 : 7),
                    decoration: BoxDecoration(
                      color: connColor.withAlpha(33),
                      borderRadius: BorderRadius.circular(prominent ? 12 : 7),
                    ),
                    child: Icon(connIcon,
                        color: connColor, size: prominent ? 20 : 20),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (printer.model != null && printer.model!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: EdgeInsets.symmetric(
                              horizontal: prominent ? 8 : 7,
                              vertical: prominent ? 4 : 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withAlpha(37),
                              borderRadius:
                                  BorderRadius.circular(prominent ? 8 : 7),
                            ),
                            child: Text(
                              printer.model!,
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontSize: prominent ? 12 : 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            _getCleanPrinterName(printer),
                            style: TextStyle(
                              fontSize: prominent ? 18 : 14,
                              fontWeight:
                                  prominent ? FontWeight.bold : FontWeight.w600,
                              color: prominent ? Colors.blue : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        if (connInfo != null)
                          Text(
                            connInfo,
                            style: TextStyle(
                              color: connColor,
                              fontSize: prominent ? 13 : 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (connInfo != null) const SizedBox(width: 8),
                        _buildStatusChip(printer.status, small: !prominent),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Tap to print',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: prominent ? 11 : 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.print,
                      color: Colors.blue,
                      size: prominent ? 22 : 20,
                    ),
                    Text(
                      'Print',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: prominent ? 10 : 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, {bool small = false}) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'connected':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'ready':
        color = Colors.blue;
        icon = Icons.radio_button_checked;
        break;
      case 'found':
        color = Colors.orange;
        icon = Icons.radio_button_unchecked;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(small ? 8 : 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: small ? 10 : 12,
            color: color,
          ),
          if (!small) ...[
            const SizedBox(width: 4),
            Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: small ? 10 : 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _validateIp(String ip) {
    final regex = RegExp(r'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}');
    if (!regex.hasMatch(ip)) return false;
    return ip.split('.').every((octet) {
      final n = int.tryParse(octet);
      return n != null && n >= 0 && n <= 255;
    });
  }

  String _getCleanPrinterName(ZebraDevice printer) {
    String name = printer.displayName ?? printer.name;

    // Remove model from name if it's concatenated
    if (printer.model != null && printer.model!.isNotEmpty) {
      final modelPattern =
          RegExp(r'\s*' + RegExp.escape(printer.model!) + r'\s*$');
      name = name.replaceAll(modelPattern, '');
    }

    return name.trim();
  }
} 