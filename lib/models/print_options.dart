import 'print_enums.dart';
import 'readiness_options.dart';

/// Options for configuring print operations
class PrintOptions {
  /// Whether to wait for print completion after sending data
  final bool waitForPrintCompletion;

  /// Readiness options for printer preparation
  final ReadinessOptions readinessOptions;

  /// Print format to use (null for auto-detection)
  final PrintFormat? format;

  const PrintOptions({
    this.waitForPrintCompletion = true,
    this.readinessOptions = const ReadinessOptions(),
    this.format,
  });

  /// Default print options with completion waiting enabled
  factory PrintOptions.defaults() => PrintOptions(
        waitForPrintCompletion: true,
        readinessOptions: ReadinessOptions.quickWithLanguage(),
      );

  /// Print options without completion waiting
  factory PrintOptions.withoutCompletion() => PrintOptions(
        waitForPrintCompletion: false,
        readinessOptions: ReadinessOptions.quickWithLanguage(),
      );

  /// Print options with specific format
  factory PrintOptions.withFormat(PrintFormat format) => PrintOptions(
        waitForPrintCompletion: true,
        readinessOptions: ReadinessOptions.quickWithLanguage(),
        format: format,
      );

  /// Creates a copy with modified options
  PrintOptions copyWith({
    bool? waitForPrintCompletion,
    ReadinessOptions? readinessOptions,
    PrintFormat? format,
  }) =>
      PrintOptions(
        waitForPrintCompletion:
            waitForPrintCompletion ?? this.waitForPrintCompletion,
        readinessOptions: readinessOptions ?? this.readinessOptions,
        format: format ?? this.format,
      );
} 