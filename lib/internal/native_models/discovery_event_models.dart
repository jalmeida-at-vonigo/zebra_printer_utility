library;

/// Non-channel constants that describe semantic event types and phases
/// for discovery diagnostic events. These are separate from method names.
class DiscoveryEventType {
  DiscoveryEventType._();
  static const String log = 'log';
}

class DiscoveryPhase {
  DiscoveryPhase._();
  static const String subnet = 'subnet';
  static const String directedBroadcast = 'directedBroadcast';
  static const String localBroadcast = 'localBroadcast';
  static const String multicast = 'multicast';
  static const String bluetoothClassic = 'btClassic';
}

/// Standard envelope for per-operation discovery events emitted by native.
/// Not exported publicly; used internally by the callback handler and printer.
class DiscoveryEventEnvelope {
  DiscoveryEventEnvelope({
    required this.method,
    required this.data,
  });

  final String method;
  final Map<String, dynamic> data;

  bool get isLogWarning => method == 'discovery_logWarning';
  String? get eventType => data['eventType'] as String?;
  String? get level => data['level'] as String?;
  String? get phase => data['phase'] as String?;
  String? get target => data['target'] as String?;
  String? get message => data['message'] as String?;
}


