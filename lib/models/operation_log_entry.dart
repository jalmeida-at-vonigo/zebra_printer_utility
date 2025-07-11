import 'package:flutter/material.dart';

/// Operation log entry for tracking and display
class OperationLogEntry {
  OperationLogEntry({
    required this.operationId,
    required this.method,
    required this.status, // 'started', 'completed', 'failed', 'timeout'
    required this.timestamp,
    this.arguments,
    this.result,
    this.error,
    this.duration,
    this.channelName,
    this.stackTrace,
  });

  final String operationId;
  final String method;
  final String status; // 'started', 'completed', 'failed', 'timeout'
  final DateTime timestamp;
  final Map<String, dynamic>? arguments;
  final dynamic result;
  final String? error;
  final Duration? duration;
  final String? channelName;
  final StackTrace? stackTrace;

  Color get statusColor {
    switch (status) {
      case 'started':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'timeout':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String get statusIcon {
    switch (status) {
      case 'started':
        return '▶️';
      case 'completed':
        return '✅';
      case 'failed':
        return '❌';
      case 'timeout':
        return '⏰';
      default:
        return '❓';
    }
  }
} 