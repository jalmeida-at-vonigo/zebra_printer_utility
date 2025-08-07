/// Native model for printer information to ensure type safety
/// between Dart and native communication
library;

import '../../models/zebra_device.dart';

class NativePrinterInfo {
  const NativePrinterInfo({
    required this.address,
    required this.name,
    this.status = 'Available',
    this.isWifi = false,
    this.isBluetooth = false,
    this.connectionType = 'Unknown',
    this.discoveryMethod = 'unknown',
    this.model,
    this.manufacturer = 'Zebra',
    this.firmwareRevision,
    this.hardwareRevision,
    this.displayName,
    this.port = 9100,
    this.dnsName,
  });

  /// Create from native dictionary
  factory NativePrinterInfo.fromNative(Map<String, dynamic> data) {
    return NativePrinterInfo(
      address: data['Address'] as String? ?? '',
      name: data['Name'] as String? ?? 'Unknown Printer',
      status: data['Status'] as String? ?? 'Available',
      isWifi: data['IsWifi'] == true || data['IsWifi'] == 'true',
      isBluetooth: data['isBluetooth'] == true || data['isBluetooth'] == 'true',
      connectionType: data['connectionType'] as String? ?? 'Unknown',
      discoveryMethod: data['discoveryMethod'] as String? ?? 'unknown',
      model: data['model'] as String?,
      manufacturer: data['manufacturer'] as String? ?? 'Zebra',
      firmwareRevision: data['firmwareRevision'] as String?,
      hardwareRevision: data['hardwareRevision'] as String?,
      displayName: data['displayName'] as String?,
      port: data['port'] as int? ?? 9100,
      dnsName: data['dnsName'] as String?,
    );
  }

  final String address;
  final String name;
  final String status;
  final bool isWifi;
  final bool isBluetooth;
  final String connectionType;
  final String discoveryMethod;

  // Optional properties
  final String? model;
  final String? manufacturer;
  final String? firmwareRevision;
  final String? hardwareRevision;
  final String? displayName;
  final int port;
  final String? dnsName;

  /// Convert to native dictionary format
  Map<String, dynamic> toNative() {
    final Map<String, dynamic> dict = {
      'Address': address,
      'Name': name,
      'Status': status,
      'IsWifi': isWifi,
      'isBluetooth': isBluetooth,
      'connectionType': connectionType,
      'discoveryMethod': discoveryMethod,
      'port': port,
    };

    // Add optional properties if present
    if (model != null) dict['model'] = model;
    if (manufacturer != null) dict['manufacturer'] = manufacturer;
    if (firmwareRevision != null) dict['firmwareRevision'] = firmwareRevision;
    if (hardwareRevision != null) dict['hardwareRevision'] = hardwareRevision;
    if (displayName != null) dict['displayName'] = displayName;
    if (dnsName != null) dict['dnsName'] = dnsName;

    return dict;
  }

  /// Convert to ZebraDevice model
  ZebraDevice toZebraDevice() {
    return ZebraDevice(
      address: address,
      name: name,
      status: status,
      isWifi: isWifi,
      isBluetooth: isBluetooth,
      brand: manufacturer ?? 'Zebra',
      model: model,
      displayName: displayName ?? _generateDisplayName(),
      manufacturer: manufacturer ?? 'Zebra',
      firmwareRevision: firmwareRevision,
      hardwareRevision: hardwareRevision,
      connectionType: connectionType,
      port: port,
    );
  }

  String _generateDisplayName() {
    if (model != null && model!.isNotEmpty) {
      return 'Zebra $model - $name';
    } else {
      return 'Zebra Printer - $name';
    }
  }

  @override
  String toString() {
    return 'NativePrinterInfo(address: $address, name: $name, status: $status, '
        'isWifi: $isWifi, isBluetooth: $isBluetooth, connectionType: $connectionType, '
        'discoveryMethod: $discoveryMethod, model: $model, manufacturer: $manufacturer, '
        'port: $port)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NativePrinterInfo &&
        other.address == address &&
        other.port == port;
  }

  @override
  int get hashCode => address.hashCode ^ port.hashCode;
}