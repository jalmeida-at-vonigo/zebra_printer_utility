import 'communication_policy_event.dart';

/// Options for configuring CommunicationPolicy behavior
class CommunicationPolicyOptions {
  final bool? skipConnectionCheck;
  final bool? skipConnectionRetry;
  final int? maxAttempts;
  final Duration? timeout;
  final void Function(CommunicationPolicyEvent event)? onEvent;

  const CommunicationPolicyOptions({
    this.skipConnectionCheck,
    this.skipConnectionRetry,
    this.maxAttempts,
    this.timeout,
    this.onEvent,
  });

  /// Returns a new options object where non-null values from [overrides] replace those in this instance
  CommunicationPolicyOptions mergeWith(CommunicationPolicyOptions? overrides) {
    if (overrides == null) return this;
    return CommunicationPolicyOptions(
      skipConnectionCheck: overrides.skipConnectionCheck ?? skipConnectionCheck,
      skipConnectionRetry: overrides.skipConnectionRetry ?? skipConnectionRetry,
      maxAttempts: overrides.maxAttempts ?? maxAttempts,
      timeout: overrides.timeout ?? timeout,
      onEvent: overrides.onEvent ?? onEvent,
    );
  }
} 