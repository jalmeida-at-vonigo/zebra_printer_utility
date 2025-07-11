/// Event types for CommunicationPolicy
enum CommunicationPolicyEventType { attempt, retry, success, error, failed }

/// Event object for CommunicationPolicy
class CommunicationPolicyEvent {
  final CommunicationPolicyEventType type;
  final int attempt;
  final int maxAttempts;
  final String message;
  final dynamic error;
  CommunicationPolicyEvent({
    required this.type,
    required this.attempt,
    required this.maxAttempts,
    required this.message,
    this.error,
  });
} 