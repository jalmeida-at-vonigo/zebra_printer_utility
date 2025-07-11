/// Detailed information about host status response
class HostStatusInfo {
  HostStatusInfo({
    required this.isOk,
    this.errorCode,
    this.errorMessage,
    required this.details,
  });

  /// Whether the printer status is OK
  final bool isOk;

  /// Numeric error code (0 = OK, non-zero = error)
  final int? errorCode;

  /// Human-readable error message
  final String? errorMessage;

  /// Additional details about the status
  final Map<String, dynamic> details;

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'isOk': isOk,
      'errorCode': errorCode,
      'errorMessage': errorMessage,
      'details': details,
    };
  }

  @override
  String toString() {
    if (isOk) {
      return 'HostStatusInfo(OK)';
    } else {
      return 'HostStatusInfo(Error: $errorMessage [Code: $errorCode])';
    }
  }
} 