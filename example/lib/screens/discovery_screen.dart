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

  // Real-time connection state tracking
  ConnectionEvent? _lastConnectionEvent;
  ZebraDevice? _connectedDevice;
  StreamSubscription<ConnectionEvent>? _connectionEventSubscription;
  StreamSubscription<ZebraDevice?>? _connectionStateSubscription;

  @override
  void initState() {
    super.initState();
    _addLog('Discovery screen initialized', 'info');
    
    // Subscribe to real-time connection events
    _subscribeToConnectionEvents();
    
    // Register for device connection status updates
    ZebraPrinter.registerDeviceUpdateCallback(_onDeviceUpdated);
  }

  void _subscribeToConnectionEvents() {
    // Listen to connection events for real-time updates
    _connectionEventSubscription = Zebra.global.connectionEvents.listen(
      (event) {
        if (!mounted) return;

        setState(() {
          _lastConnectionEvent = event;
        });

        // Log connection events with rich details
        switch (event.type) {
          case ConnectionEventType.connected:
            _addLog('Printer connected', 'success',
                details:
                    '${event.printerAddress}: ${event.message}\nSource: ${event.metadata['context'] ?? 'unknown'}');
            break;
          case ConnectionEventType.lost:
            _addLog('Connection lost', 'warning',
                details:
                    '${event.printerAddress}: ${event.message}\nSource: ${event.metadata['context'] ?? 'unknown'}');
            break;
          case ConnectionEventType.failed:
            _addLog('Connection failed', 'error',
                details: '${event.printerAddress}: ${event.message}');
            break;
          case ConnectionEventType.disconnected:
            _addLog('Printer disconnected', 'info',
                details: '${event.printerAddress}: ${event.message}');
            break;
        }
      },
      onError: (error) {
        _addLog('Connection event error', 'error', details: error.toString());
      },
    );

    // Listen to connection state changes to track the currently connected device
    _connectionStateSubscription = Zebra.global.connection.listen(
      (device) {
        if (!mounted) return;
        setState(() {
          _connectedDevice = device;
        });
      },
    );
  }

  /// Handle device updates to show real-time connection status changes
  void _onDeviceUpdated(ZebraDevice updatedDevice) {
    if (!mounted) return;

    // Find and update the device in our list
    final index =
        _devices.indexWhere((d) => d.address == updatedDevice.address);
    if (index != -1) {
      setState(() {
        _devices[index] = updatedDevice;
      });

      // Log connection status changes
      _addLog(
        'Device status updated',
        updatedDevice.isConnected ? 'success' : 'info',
        details: 'Name: ${updatedDevice.name}\n'
            'Address: ${updatedDevice.address}\n'
            'Status: ${updatedDevice.isConnected ? "Connected" : "Disconnected"}\n'
            'Type: ${updatedDevice.isWifi ? "WiFi" : "Bluetooth"}',
      );
    }
  }

  @override
  void dispose() {
    // Unregister device update callback
    ZebraPrinter.unregisterDeviceUpdateCallback(_onDeviceUpdated);
    
    // Cancel all subscriptions
    _discoverySubscription?.cancel();
    _connectionEventSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    
    // Stop discovery if still running
    if (_isDiscovering) {
      Zebra.global.stopDiscovery();
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
      // Start streaming discovery
      final deviceStream = Zebra.global.discoverPrintersStream(
        timeout: Duration(seconds: _discoveryTimeout),
        includeWifi: _includeWifi,
        includeBluetooth: _includeBluetooth,
      );

      // Subscribe to the discovery stream for real-time updates
      _discoverySubscription = deviceStream.listen(
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
      final result = await Zebra.global.stopDiscovery();
      
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
    _addLog('Connecting to ${device.name}...', 'info',
        details: 'Discovery will continue running in the background');

    try {
      final result = await Zebra.global.connect(device.address);
      
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
        // Real-time connection status
        _buildConnectionStatusCard(),
        const SizedBox(height: 16),
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
    return Column(
      children: [
        // Real-time connection status (full width)
        _buildConnectionStatusCard(),
        const SizedBox(height: 16),
        // Main content
        Expanded(
          child: Row(
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
          ),
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
                        trailing: _buildDeviceActionButton(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Build real-time connection status card showing current connection state
  Widget _buildConnectionStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _lastConnectionEvent?.type.icon ?? Icons.link_off,
                  size: 20,
                  color: _getConnectionStatusColor(),
                ),
                const SizedBox(width: 8),
                Text(
                  'Connection Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const Spacer(),
                // Real-time status indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getConnectionStatusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getConnectionStatusColor().withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getConnectionStatusColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _lastConnectionEvent?.type.displayName ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getConnectionStatusColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Connection details
            if (_connectedDevice != null) ...[
              Row(
                children: [
                  Icon(
                    _connectedDevice!.isWifi ? Icons.wifi : Icons.bluetooth,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _connectedDevice!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _connectedDevice!.address,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Disconnect button
                  OutlinedButton(
                    onPressed: _disconnectFromPrinter,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Last event message
              if (_lastConnectionEvent?.message != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text(
                    _lastConnectionEvent!.message!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ] else ...[
              // No connection
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No printer connected. Discover and connect to a printer below.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Get appropriate color for current connection status
  Color _getConnectionStatusColor() {
    if (_lastConnectionEvent == null) {
      return Colors.grey;
    }
    return _lastConnectionEvent!.type.color;
  }

  /// Disconnect from the currently connected printer
  Future<void> _disconnectFromPrinter() async {
    if (_connectedDevice == null) return;

    _addLog('Disconnecting from ${_connectedDevice!.name}...', 'info');

    try {
      final result = await Zebra.global.disconnect();

      if (result.success) {
        _addLog('Disconnected successfully', 'success');
      } else {
        _addLog('Failed to disconnect', 'error',
            details: result.error?.message);
      }
    } catch (e) {
      _addLog('Disconnect error', 'error', details: '$e');
    }
  }

  /// Build the action button for each device (Connect/Connected/Disconnect)
  Widget _buildDeviceActionButton(ZebraDevice device) {
    final isConnected = device.isConnected;
    final isCurrentDevice = _connectedDevice?.address == device.address;

    if (isConnected && isCurrentDevice) {
      // This device is currently connected
      return ElevatedButton.icon(
        onPressed: _disconnectFromPrinter,
        icon: const Icon(Icons.link_off, size: 16),
        label: const Text('Disconnect'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    } else if (isConnected) {
      // This device is connected but not the current one (should not happen, but handle gracefully)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.green),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green),
            SizedBox(width: 4),
            Text(
              'Connected',
              style: TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      // This device is not connected - show connect button
      return OutlinedButton.icon(
        onPressed: () => _connectToDevice(device),
        icon: const Icon(Icons.link, size: 16),
        label: const Text('Connect'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    }
  }
} 