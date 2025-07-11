/// Event types for CommunicationPolicy
enum CommunicationPolicyEventType { attempt, retry, success, error, failed }

/// Event that occurs during communication policy execution
class CommunicationPolicyEvent {
  CommunicationPolicyEvent({
    required this.type,
    required this.attempt,
    required this.maxAttempts,
    required this.message,
    this.error,
  });

  final CommunicationPolicyEventType type;
  final int attempt;
  final int maxAttempts;
  final String message;
  final dynamic error;
} 