/// Enriched error information from native operations
/// Preserves structured error data for proper error handling in Dart
class EnrichedNativeError {
  const EnrichedNativeError({
    required this.message,
    required this.code,
    this.nativeError,
    this.nativeErrorCode,
    this.nativeErrorDomain,
    this.context,
    required this.timestamp,
    this.nativeStackTrace,
    required this.operationId,
    required this.instanceId,
    required this.queue,
  });

  final String message;
  final String code;
  final String? nativeError;
  final int? nativeErrorCode;
  final String? nativeErrorDomain;
  final Map<String, dynamic>? context;
  final String timestamp;
  final String? nativeStackTrace;
  final String operationId;
  final String instanceId;
  final String queue;

  /// Convert to map for sending to native
  Map<String, dynamic> toNative() {
    final map = <String, dynamic>{
      'message': message,
      'code': code,
      'timestamp': timestamp,
      'operationId': operationId,
      'instanceId': instanceId,
      'queue': queue,
    };

    if (nativeError != null) {
      map['nativeError'] = nativeError;
    }

    if (nativeErrorCode != null) {
      map['nativeErrorCode'] = nativeErrorCode;
    }

    if (nativeErrorDomain != null) {
      map['nativeErrorDomain'] = nativeErrorDomain;
    }

    if (context != null) {
      map['context'] = context;
    }

    if (nativeStackTrace != null) {
      map['nativeStackTrace'] = nativeStackTrace;
    }

    return map;
  }

  /// Convert to legacy string format for backward compatibility
  String toLegacyString() {
    final parts = <String>[message];

    if (code != 'UNKNOWN_ERROR') {
      parts.add('Code: $code');
    }

    if (nativeError != null) {
      parts.add('Native: $nativeError');
    }

    if (nativeErrorCode != null) {
      parts.add('Native Code: $nativeErrorCode');
    }

    if (nativeErrorDomain != null) {
      parts.add('Native Domain: $nativeErrorDomain');
    }

    if (context != null && context!.isNotEmpty) {
      final contextStr =
          context!.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      parts.add('Context: {$contextStr}');
    }

    if (timestamp.isNotEmpty) {
      parts.add('Time: $timestamp');
    }

    if (nativeStackTrace != null) {
      parts.add('Native Stack: $nativeStackTrace');
    }

    return parts.join(' | ');
  }

  @override
  String toString() {
    return 'EnrichedNativeError(message: $message, code: $code, operationId: $operationId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnrichedNativeError &&
        other.message == message &&
        other.code == code &&
        other.operationId == operationId;
  }

  @override
  int get hashCode {
    return Object.hash(message, code, operationId);
  }
}
