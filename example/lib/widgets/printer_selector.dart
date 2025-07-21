import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';

/// A reusable printer selector widget that handles discovery and connection
class PrinterSelector extends StatefulWidget {
  final Function(ZebraDevice?) onPrinterChanged;
  final Function(String message, String level)? onLog;

  const PrinterSelector({
    super.key,
    required this.onPrinterChanged,
    this.onLog,
  });

  @override
  State<PrinterSelector> createState() => _PrinterSelectorState();
}

class _PrinterSelectorState extends State<PrinterSelector> {
  final List<ZebraDevice> _devices = [];
  ZebraDevice? _selectedDevice;
  bool _isDiscovering = false;
  bool _isConnecting = false;
  String _status = 'No printer selected';

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final result = await Zebra.isConnected();
    if (mounted && result.success && result.data == true) {
      setState(() {
        _status = 'Connected';
      });
    }
  }

  void _log(String message, String level) {
    widget.onLog?.call(message, level);
  }

  Future<void> _startDiscovery() async {
    if (_isDiscovering) return;

    setState(() {
      _isDiscovering = true;
      _devices.clear();
    });

    _log('Starting printer discovery...', 'info');

    try {
      final result = await Zebra.discoverPrintersStream(
        timeout: const Duration(seconds: 15),
        includeWifi: true,
        includeBluetooth: true,
      );
      
      if (result.success && result.data != null) {
        await for (final devices in result.data!) {
          if (!mounted) break;
          
          setState(() {
            _devices.clear();
            _devices.addAll(devices);
          });
          
          _log('Found ${devices.length} printer(s)', 'info');
        }
      } else {
        _log('Discovery failed: ${result.error?.message}', 'error');
      }
    } catch (e) {
      _log('Discovery error: $e', 'error');
    } finally {
      if (mounted) {
        setState(() {
          _isDiscovering = false;
        });
      }
    }
  }

  Future<void> _connect(ZebraDevice device) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
      _status = 'Connecting...';
    });

    _log('Connecting to ${device.name}...', 'info');

    try {
      // Disconnect from current printer if connected
      if (_selectedDevice != null) {
        await Zebra.disconnect();
      }

      // Connect to new printer
      final result = await Zebra.connect(device.address);
      
      if (mounted) {
        if (result.success) {
          setState(() {
            _selectedDevice = device;
            _status = 'Connected to ${device.name}';
          });
          widget.onPrinterChanged(device);
          _log('Connected successfully', 'success');
        } else {
          setState(() {
            _status = 'Connection failed';
          });
          _log('Connection failed: ${result.error?.message}', 'error');
        }
      }
    } catch (e) {
      _log('Connection error: $e', 'error');
      if (mounted) {
        setState(() {
          _status = 'Connection error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    _log('Disconnecting...', 'info');
    
    try {
      final result = await Zebra.disconnect();
      if (result.success) {
        if (mounted) {
          setState(() {
            _selectedDevice = null;
            _status = 'Disconnected';
          });
          widget.onPrinterChanged(null);
          _log('Disconnected successfully', 'success');
        }
      } else {
        _log('Disconnect failed: ${result.error?.message}', 'error');
      }
    } catch (e) {
      _log('Disconnect error: $e', 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.print,
                        size: 20,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Printer Selection',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      // Discovery button
                      IconButton(
                        onPressed: _isDiscovering ? null : _startDiscovery,
                        icon: _isDiscovering
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        tooltip: 'Discover printers',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Status
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _selectedDevice != null
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _status,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Content
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 120,
                maxHeight: 280,
              ),
              child: SingleChildScrollView(
                child: _buildContent(),
              ),
            ),
            // Disconnect button
            if (_selectedDevice != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: _disconnect,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedDevice != null) {
      return _buildSelectedPrinter();
    }

    if (_devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.print_disabled,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _isDiscovering
                    ? 'Searching for printers...'
                    : 'No printers found',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              if (!_isDiscovering)
                TextButton.icon(
                  onPressed: _startDiscovery,
                  icon: const Icon(Icons.search),
                  label: const Text('Start Discovery'),
                ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        final isSelected = device.address == _selectedDevice?.address;
        
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey[300],
            radius: 18,
            child: Icon(
              device.isWifi ? Icons.wifi : Icons.bluetooth,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 18,
            ),
          ),
          title: Text(device.name),
          subtitle: Text(device.address),
          trailing: _isConnecting && !isSelected
              ? null
              : TextButton(
                  onPressed: isSelected || _isConnecting
                      ? null
                      : () => _connect(device),
                  child: Text(isSelected ? 'Connected' : 'Connect'),
                ),
          selected: isSelected,
        );
      },
    );
  }

  Widget _buildSelectedPrinter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Printer icon
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _selectedDevice!.isWifi ? Icons.wifi : Icons.bluetooth,
                size: 40,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Printer info
          _buildInfoRow('Name', _selectedDevice!.name),
          _buildInfoRow('Address', _selectedDevice!.address),
          _buildInfoRow('Type', _selectedDevice!.isWifi ? 'Network' : 'Bluetooth'),
          if (_selectedDevice!.model != null)
            _buildInfoRow('Model', _selectedDevice!.model!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 