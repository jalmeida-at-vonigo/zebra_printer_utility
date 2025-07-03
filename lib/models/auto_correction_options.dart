/// Configuration options for automatic printer issue correction
class AutoCorrectionOptions {
  /// Enable automatic unpause when printer is paused
  final bool enableUnpause;

  /// Enable automatic error clearing for recoverable errors
  final bool enableClearErrors;

  /// Enable automatic reconnection on connection loss
  final bool enableReconnect;

  /// Enable automatic printer language switching based on data format
  final bool enableLanguageSwitch;

  /// Enable automatic calibration when needed
  final bool enableCalibration;

  /// Enable automatic buffer clearing before printing (recommended for CPCL)
  final bool enableBufferClear;

  /// Maximum number of correction attempts
  final int maxAttempts;

  /// Delay between correction attempts in milliseconds
  final int attemptDelayMs;

  const AutoCorrectionOptions({
    this.enableUnpause = true,
    this.enableClearErrors = true,
    this.enableReconnect = true,
    this.enableLanguageSwitch = false,
    this.enableCalibration = false,
    this.enableBufferClear = false,
    this.maxAttempts = 3,
    this.attemptDelayMs = 500,
  });

  /// Enable all auto-correction features
  factory AutoCorrectionOptions.all() {
    return const AutoCorrectionOptions(
      enableUnpause: true,
      enableClearErrors: true,
      enableReconnect: true,
      enableLanguageSwitch: true,
      enableCalibration: true,
      enableBufferClear: true,
    );
  }

  /// Disable all auto-correction features
  factory AutoCorrectionOptions.none() {
    return const AutoCorrectionOptions(
      enableUnpause: false,
      enableClearErrors: false,
      enableReconnect: false,
      enableLanguageSwitch: false,
      enableCalibration: false,
      enableBufferClear: false,
    );
  }

  /// Enable only safe auto-corrections (no calibration or language switching)
  factory AutoCorrectionOptions.safe() {
    return const AutoCorrectionOptions(
      enableUnpause: true,
      enableClearErrors: true,
      enableReconnect: true,
      enableLanguageSwitch: false,
      enableCalibration: false,
      enableBufferClear: false,
    );
  }

  /// Factory constructor optimized for regular print operations
  /// Includes buffer clearing for reliability
  factory AutoCorrectionOptions.print() {
    return const AutoCorrectionOptions(
      enableUnpause: true,
      enableClearErrors: true,
      enableReconnect: false,
      enableLanguageSwitch: true,
      enableBufferClear: true,
    );
  }

  /// Factory constructor optimized for autoPrint operations
  /// Includes all safety features
  factory AutoCorrectionOptions.autoPrint() {
    return const AutoCorrectionOptions(
      enableUnpause: true,
      enableClearErrors: true,
      enableReconnect: true,
      enableLanguageSwitch: true,
      enableCalibration: true,
      enableBufferClear: true,
    );
  }

  /// Create a copy with modified values
  AutoCorrectionOptions copyWith({
    bool? enableUnpause,
    bool? enableClearErrors,
    bool? enableReconnect,
    bool? enableLanguageSwitch,
    bool? enableCalibration,
    bool? enableBufferClear,
    int? maxAttempts,
    int? attemptDelayMs,
  }) {
    return AutoCorrectionOptions(
      enableUnpause: enableUnpause ?? this.enableUnpause,
      enableClearErrors: enableClearErrors ?? this.enableClearErrors,
      enableReconnect: enableReconnect ?? this.enableReconnect,
      enableLanguageSwitch: enableLanguageSwitch ?? this.enableLanguageSwitch,
      enableCalibration: enableCalibration ?? this.enableCalibration,
      enableBufferClear: enableBufferClear ?? this.enableBufferClear,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      attemptDelayMs: attemptDelayMs ?? this.attemptDelayMs,
    );
  }

  /// Check if any correction is enabled
  bool get hasAnyEnabled =>
      enableUnpause ||
      enableClearErrors ||
      enableReconnect ||
      enableLanguageSwitch ||
      enableCalibration ||
      enableBufferClear;

  @override
  String toString() {
    return 'AutoCorrectionOptions('
        'unpause: $enableUnpause, '
        'clearErrors: $enableClearErrors, '
        'reconnect: $enableReconnect, '
        'languageSwitch: $enableLanguageSwitch, '
        'calibration: $enableCalibration, '
        'bufferClear: $enableBufferClear, '
        'maxAttempts: $maxAttempts, '
        'attemptDelayMs: $attemptDelayMs)';
  }
}
