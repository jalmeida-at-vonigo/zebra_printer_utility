import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';

import '../widgets/log_panel.dart';
import '../widgets/responsive_layout.dart';

/// Discovery screen demonstrating printer discovery capabilities
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final List<LogEntry> _logs = [];
  final List<ZebraDevice> _devices = [];
  bool _isDiscovering = false;
  int _discoveryTimeout = 15;
  bool _includeWifi = true;
  bool _includeBluetooth = true;
  StreamSubscription<List<ZebraDevice>>? _discoverySubscription;

  @override
  void initState() {
    super.initState();
    _addLog('Discovery screen initialized', 'info');
  }

  @override
  void dispose() {
    // Cancel any active discovery subscription
    _discoverySubscription?.cancel();
    // Stop discovery if still running
    if (_isDiscovering) {
      Zebra.stopDiscovery();
    }
    super.dispose();
  }

  void _addLog(String message, String level, {String? details}) {
    if (!mounted) return;
    setState(() {
      _logs.add(LogEntry(
        timestamp: DateTime.now(),
        level: level,
        message: message,
        details: details,
      ));
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
    _addLog('Logs cleared', 'info');
  }

  Future<void> _startDiscovery() async {
    if (_isDiscovering) return;

    // Cancel any existing subscription
    await _discoverySubscription?.cancel();

    setState(() {
      _isDiscovering = true;
      _devices.clear();
    });

    _addLog('Starting discovery...', 'info', 
      details: 'Timeout: ${_discoveryTimeout}s, WiFi: $_includeWifi, Bluetooth: $_includeBluetooth');

    try {
      final result = await Zebra.discoverPrintersStream(
        timeout: Duration(seconds: _discoveryTimeout),
        includeWifi: _includeWifi,
        includeBluetooth: _includeBluetooth,
      );

      if (result.success && result.data != null) {
        // Subscribe to the discovery stream for real-time updates
        _discoverySubscription = result.data!.listen(
          (devices) {
            if (!mounted) return;
            
            // Real-time update: Update UI immediately when printers are found
            final previousDeviceCount = _devices.length;
            setState(() {
              _devices.clear();
              _devices.addAll(devices);
            });
            
            // Log only new discoveries to avoid spam
            if (devices.length > previousDeviceCount) {
              _addLog('Found ${devices.length} printer(s)', 'info');
              
              // Log details about new devices only
              final newDevices = devices.skip(previousDeviceCount);
              for (final device in newDevices) {
                _addLog(
                  'Printer discovered',
                  'success',
                  details: 'Name: ${device.name}\n'
                      'Address: ${device.address}\n'
                      'Type: ${device.isWifi ? "WiFi" : "Bluetooth"}\n'
                      'Model: ${device.model ?? "Unknown"}',
                );
              }
            }
          },
          onError: (error) {
            if (!mounted) return;
            _addLog('Discovery error', 'error', details: '$error');
            setState(() {
              _isDiscovering = false;
            });
          },
          onDone: () {
            if (!mounted) return;
            _addLog('Discovery completed', 'success',
                details: 'Total printers found: ${_devices.length}');
            setState(() {
              _isDiscovering = false;
            });
          },
        );
      } else {
        _addLog('Discovery failed', 'error', details: result.error?.message);
        setState(() {
          _isDiscovering = false;
        });
      }
    } catch (e, stack) {
      _addLog('Discovery error', 'error', details: '$e\n$stack');
      setState(() {
        _isDiscovering = false;
      });
    }
  }

  Future<void> _stopDiscovery() async {
    if (!_isDiscovering) return;

    _addLog('Stopping discovery...', 'info');

    try {
      // Cancel the stream subscription first
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;

      // Then stop the discovery service
      final result = await Zebra.stopDiscovery();
      
      setState(() {
        _isDiscovering = false;
      });
      
      if (result.success) {
        _addLog('Discovery stopped', 'success');
      } else {
        _addLog('Failed to stop discovery', 'error', details: result.error?.message);
      }
    } catch (e) {
      _addLog('Error stopping discovery', 'error', details: '$e');
      setState(() {
        _isDiscovering = false;
      });
    }
  }

  Future<void> _connectToDevice(ZebraDevice device) async {
    // Stop discovery when user selects a printer
    if (_isDiscovering) {
      await _stopDiscovery();
    }
    
    _addLog('Connecting to ${device.name}...', 'info');

    try {
      final result = await Zebra.connect(device.address);
      
      if (result.success) {
        _addLog('Connected successfully', 'success', 
          details: 'Connected to ${device.name} at ${device.address}');
      } else {
        _addLog('Connection failed', 'error', details: result.error?.message);
      }
    } catch (e) {
      _addLog('Connection error', 'error', details: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    
    return ResponsiveContainer(
      maxWidth: 1200,
      child: isMobile
          ? _buildMobileLayout()
          : _buildTabletLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Discovery controls
        _buildDiscoveryControls(),
        const SizedBox(height: 16),
        // Device list
        Expanded(
          child: _buildDeviceList(),
        ),
        const SizedBox(height: 16),
        // Log panel
        SizedBox(
          height: 200,
          child: LogPanel(
            logs: _logs,
            onClear: _clearLogs,
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Discovery controls and logs
        SizedBox(
          width: 400,
          child: Column(
            children: [
              // Discovery controls
              _buildDiscoveryControls(),
              const SizedBox(height: 16),
              // Log panel
              Expanded(
                child: LogPanel(
                  logs: _logs,
                  onClear: _clearLogs,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Right side - Device list
        Expanded(
          child: _buildDeviceList(),
        ),
      ],
    );
  }

  Widget _buildDiscoveryControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.search,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Discovery Settings',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Timeout slider
            Row(
              children: [
                const Text('Timeout:'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _discoveryTimeout.toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    label: '${_discoveryTimeout}s',
                    onChanged: _isDiscovering ? null : (value) {
                      setState(() {
                        _discoveryTimeout = value.toInt();
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('${_discoveryTimeout}s'),
                ),
              ],
            ),
            // Connection type filters
            Row(
              children: [
                Checkbox(
                  value: _includeWifi,
                  onChanged: _isDiscovering ? null : (value) {
                    setState(() {
                      _includeWifi = value ?? true;
                    });
                  },
                ),
                const Text('WiFi'),
                const SizedBox(width: 16),
                Checkbox(
                  value: _includeBluetooth,
                  onChanged: _isDiscovering ? null : (value) {
                    setState(() {
                      _includeBluetooth = value ?? true;
                    });
                  },
                ),
                const Text('Bluetooth'),
              ],
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isDiscovering ? null : _startDiscovery,
                    icon: _isDiscovering
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isDiscovering ? 'Discovering...' : 'Start Discovery'),
                  ),
                ),
                if (_isDiscovering) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _stopDiscovery,
                    child: const Text('Stop'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.devices,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Discovered Printers',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const Spacer(),
                Chip(
                  label: Text('${_devices.length}'),
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                ),
              ],
            ),
          ),
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                              : 'No printers discovered',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: device.isWifi
                              ? Colors.blue[100]
                              : Colors.blue[50],
                          child: Icon(
                            device.isWifi ? Icons.wifi : Icons.bluetooth,
                            color: device.isWifi
                                ? Colors.blue[700]
                                : Colors.blue[600],
                          ),
                        ),
                        title: Text(device.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(device.address),
                            if (device.model != null)
                              Text(
                                'Model: ${device.model}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                        trailing: OutlinedButton(
                          onPressed: () => _connectToDevice(device),
                          child: const Text('Connect'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 