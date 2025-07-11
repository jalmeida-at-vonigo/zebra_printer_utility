/// Options for configuring printer readiness operations
class ReadinessOptions {
  // Check options
  /// Whether to check printer connection
  final bool checkConnection;
  
  /// Whether to check media status
  final bool checkMedia;
  
  /// Whether to check head status
  final bool checkHead;
  
  /// Whether to check pause status
  final bool checkPause;
  
  /// Whether to check for errors
  final bool checkErrors;
  
  /// Whether to check printer language
  final bool checkLanguage;
  
  // Fix options
  /// Whether to fix paused printer
  final bool fixPausedPrinter;
  
  /// Whether to fix printer errors
  final bool fixPrinterErrors;
  
  /// Whether to fix media calibration
  final bool fixMediaCalibration;
  
  /// Whether to fix language mismatch
  final bool fixLanguageMismatch;
  
  /// Whether to fix buffer issues
  final bool fixBufferIssues;
  
  /// Whether to clear buffer
  final bool clearBuffer;
  
  /// Whether to flush buffer
  final bool flushBuffer;
  
  // Behavior options
  /// Delay between checks
  final Duration checkDelay;
  
  /// Maximum number of attempts for operations
  final int maxAttempts;
  
  /// Whether to enable verbose logging
  final bool verboseLogging;
  
  /// Constructor with all options
  const ReadinessOptions({
    this.checkConnection = true,
    this.checkMedia = true,
    this.checkHead = true,
    this.checkPause = true,
    this.checkErrors = true,
    this.checkLanguage = false,
    this.fixPausedPrinter = true,
    this.fixPrinterErrors = true,
    this.fixMediaCalibration = false,
    this.fixLanguageMismatch = false,
    this.fixBufferIssues = false,
    this.clearBuffer = false,
    this.flushBuffer = false,
    this.checkDelay = const Duration(milliseconds: 100),
    this.maxAttempts = 3,
    this.verboseLogging = false,
  });
  
  /// Quick readiness check with basic fixes
  factory ReadinessOptions.quick() => const ReadinessOptions(
    checkConnection: true,
    checkMedia: true,
    checkHead: true,
    checkPause: true,
    fixPausedPrinter: true,
    fixPrinterErrors: true,
  );
  
  /// Comprehensive readiness check with all fixes
  factory ReadinessOptions.comprehensive() => const ReadinessOptions(
    checkConnection: true,
    checkMedia: true,
    checkHead: true,
    checkPause: true,
    checkErrors: true,
    checkLanguage: true,
    fixPausedPrinter: true,
    fixPrinterErrors: true,
    fixMediaCalibration: true,
    fixLanguageMismatch: true,
    fixBufferIssues: true,
    clearBuffer: true,
    flushBuffer: true,
  );
  
  /// Optimized for print operations
  factory ReadinessOptions.forPrinting() => const ReadinessOptions(
    checkConnection: true,
    checkMedia: true,
    checkHead: true,
    checkPause: true,
    checkErrors: true,
    fixPausedPrinter: true,
    fixPrinterErrors: true,
    clearBuffer: true,
    flushBuffer: true,
  );
  
  /// Creates a copy with modified options
  ReadinessOptions copyWith({
    bool? checkConnection,
    bool? checkMedia,
    bool? checkHead,
    bool? checkPause,
    bool? checkErrors,
    bool? checkLanguage,
    bool? fixPausedPrinter,
    bool? fixPrinterErrors,
    bool? fixMediaCalibration,
    bool? fixLanguageMismatch,
    bool? fixBufferIssues,
    bool? clearBuffer,
    bool? flushBuffer,
    Duration? checkDelay,
    int? maxAttempts,
    bool? verboseLogging,
  }) => ReadinessOptions(
    checkConnection: checkConnection ?? this.checkConnection,
    checkMedia: checkMedia ?? this.checkMedia,
    checkHead: checkHead ?? this.checkHead,
    checkPause: checkPause ?? this.checkPause,
    checkErrors: checkErrors ?? this.checkErrors,
    checkLanguage: checkLanguage ?? this.checkLanguage,
    fixPausedPrinter: fixPausedPrinter ?? this.fixPausedPrinter,
    fixPrinterErrors: fixPrinterErrors ?? this.fixPrinterErrors,
    fixMediaCalibration: fixMediaCalibration ?? this.fixMediaCalibration,
    fixLanguageMismatch: fixLanguageMismatch ?? this.fixLanguageMismatch,
    fixBufferIssues: fixBufferIssues ?? this.fixBufferIssues,
    clearBuffer: clearBuffer ?? this.clearBuffer,
    flushBuffer: flushBuffer ?? this.flushBuffer,
    checkDelay: checkDelay ?? this.checkDelay,
    maxAttempts: maxAttempts ?? this.maxAttempts,
    verboseLogging: verboseLogging ?? this.verboseLogging,
  );
  
  @override
  String toString() {
    return 'ReadinessOptions('
        'checks: [${checkConnection ? 'connection' : ''}${checkMedia ? ', media' : ''}${checkHead ? ', head' : ''}${checkPause ? ', pause' : ''}${checkErrors ? ', errors' : ''}${checkLanguage ? ', language' : ''}]'
        'fixes: [${fixPausedPrinter ? 'unpause' : ''}${fixPrinterErrors ? ', clearErrors' : ''}${fixMediaCalibration ? ', calibrate' : ''}${fixLanguageMismatch ? ', language' : ''}${fixBufferIssues ? ', buffer' : ''}${clearBuffer ? ', clearBuffer' : ''}${flushBuffer ? ', flushBuffer' : ''}]'
        ')';
  }
} 