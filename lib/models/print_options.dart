import '../zebra_printer_manager.dart';

import 'print_enums.dart';
import 'readiness_options.dart';

/// Options for configuring print operations
class PrintOptions {
  const PrintOptions({
    this.waitForPrintCompletion,
    this.readinessOptions,
    this.format,
    this.cancellationToken,
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

  /// Whether to wait for print completion after sending data
  final bool? waitForPrintCompletion;

  /// Readiness options for printer preparation
  final ReadinessOptions? readinessOptions;

  /// Print format to use (null for auto-detection)
  final PrintFormat? format;

  /// Cancellation token for aborting operations
  final CancellationToken? cancellationToken;

  /// Gets waitForPrintCompletion with default value

  bool get waitForPrintCompletionOrDefault => waitForPrintCompletion ?? true;

  /// Gets readinessOptions with default value
  ReadinessOptions get readinessOptionsOrDefault =>
      readinessOptions ?? ReadinessOptions.quickWithLanguage();

  /// Gets format with default value (null for auto-detection)
  PrintFormat? get formatOrDefault => format;

  /// Creates a copy by merging with another PrintOptions, copying only non-null properties
  PrintOptions copyWith(PrintOptions? other) {
    return PrintOptions(
      waitForPrintCompletion:
          other?.waitForPrintCompletion ?? waitForPrintCompletion,
      readinessOptions: other?.readinessOptions ?? readinessOptions,
      format: other?.format ?? format,
      cancellationToken: other?.cancellationToken ?? cancellationToken,
    );
  }
} 