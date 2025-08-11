import 'package:flutter/material.dart';

/// Events related to printer connection state changes
/// These events provide real-time updates about connection status
/// for immediate UI feedback and responsiveness
class ConnectionEvent {
  const ConnectionEvent({
    required this.type,
    required this.timestamp,
    this.printerAddress,
    this.message,
    this.metadata = const {},
  });

  /// Create a connection established event
  factory ConnectionEvent.connected({
    required String printerAddress,
    String? message,
    Map<String, dynamic>? metadata,
  }) {
    return ConnectionEvent(
      type: ConnectionEventType.connected,
      timestamp: DateTime.now(),
      printerAddress: printerAddress,
      message: message ?? 'Connected to printer',
      metadata: metadata ?? {},
    );
  }

  /// Create a connection lost event
  factory ConnectionEvent.lost({
    required String printerAddress,
    String? reason,
    Map<String, dynamic>? metadata,
  }) {
    return ConnectionEvent(
      type: ConnectionEventType.lost,
      timestamp: DateTime.now(),
      printerAddress: printerAddress,
      message: reason ?? 'Connection lost',
      metadata: metadata ?? {},
    );
  }

  /// Create a connection failed event
  factory ConnectionEvent.failed({
    required String printerAddress,
    String? reason,
    Map<String, dynamic>? metadata,
  }) {
    return ConnectionEvent(
      type: ConnectionEventType.failed,
      timestamp: DateTime.now(),
      printerAddress: printerAddress,
      message: reason ?? 'Connection failed',
      metadata: metadata ?? {},
    );
  }

  /// Create a disconnected event
  factory ConnectionEvent.disconnected({
    required String printerAddress,
    String? reason,
    Map<String, dynamic>? metadata,
  }) {
    return ConnectionEvent(
      type: ConnectionEventType.disconnected,
      timestamp: DateTime.now(),
      printerAddress: printerAddress,
      message: reason ?? 'Disconnected from printer',
      metadata: metadata ?? {},
    );
  }

  final ConnectionEventType type;
  final DateTime timestamp;
  final String? printerAddress;
  final String? message;
  final Map<String, dynamic> metadata;

  @override
  String toString() {
    return 'ConnectionEvent(type: $type, address: $printerAddress, message: $message)';
  }
}

/// Types of connection events
enum ConnectionEventType {
  /// Successfully connected to printer
  connected,
  
  /// Connection was lost unexpectedly (e.g., printer powered off, out of range)
  lost,
  
  /// Connection attempt failed
  failed,
  
  /// Intentionally disconnected from printer
  disconnected,
}

/// Extension for display-friendly names
extension ConnectionEventTypeExtension on ConnectionEventType {
  String get displayName {
    switch (this) {
      case ConnectionEventType.connected:
        return 'Connected';
      case ConnectionEventType.lost:
        return 'Connection Lost';
      case ConnectionEventType.failed:
        return 'Connection Failed';
      case ConnectionEventType.disconnected:
        return 'Disconnected';
    }
  }

  /// Get appropriate icon for the connection state
  IconData get icon {
    switch (this) {
      case ConnectionEventType.connected:
        return Icons.wifi;
      case ConnectionEventType.lost:
        return Icons.wifi_off;
      case ConnectionEventType.failed:
        return Icons.error;
      case ConnectionEventType.disconnected:
        return Icons.link_off;
    }
  }

  /// Get appropriate color for the connection state
  Color get color {
    switch (this) {
      case ConnectionEventType.connected:
        return Colors.green;
      case ConnectionEventType.lost:
        return Colors.red;
      case ConnectionEventType.failed:
        return Colors.orange;
      case ConnectionEventType.disconnected:
        return Colors.grey;
    }
  }
}
