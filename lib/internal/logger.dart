import 'package:flutter/foundation.dart';

/// Logger levels for controlling output verbosity
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Internal logger for the Zebra printer plugin
///
/// Provides consistent logging with levels and prefixes.
/// In release mode, only warnings and errors are logged.
class Logger {
  Logger({
    this.prefix = 'ZebraPrinter',
    this.minimumLevel = LogLevel.info,
    this.customLogger,
  });

  /// Create a logger with a specific prefix
  factory Logger.withPrefix(String prefix) {
    return Logger(prefix: prefix);
  }

  final String prefix;
  final LogLevel minimumLevel;
  final void Function(String message)? customLogger;

  /// Global logger instance
  static final Logger instance = Logger();

  void debug(String message) {
    _log(LogLevel.debug, message);
  }

  void info(String message) {
    _log(LogLevel.info, message);
  }

  void warning(String message) {
    _log(LogLevel.warning, message);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message);
    if (error != null) {
      _log(LogLevel.error, 'Error: $error');
    }
    if (stackTrace != null && kDebugMode) {
      _log(LogLevel.error, 'Stack trace:\n$stackTrace');
    }
  }

  void _log(LogLevel level, String message) {
    // Skip debug logs in release mode
    if (!kDebugMode && level == LogLevel.debug) {
      return;
    }

    // Check minimum level
    if (level.index < minimumLevel.index) {
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().trim();
    final formattedMessage =
        '[$timestamp] [zebrautil] [$prefix] $levelStr: $message';

    if (customLogger != null) {
      customLogger!(formattedMessage);
    } else if (kDebugMode) {
      // In debug mode, use debugPrint
      debugPrint(formattedMessage);
    } else {
      // In release mode, only log warnings and errors
      if (level == LogLevel.warning || level == LogLevel.error) {
        print(formattedMessage); // ignore: avoid_print
      }
    }
  }
}

/// Extension to easily create child loggers
extension LoggerExtension on Logger {
  Logger child(String suffix) {
    return Logger(prefix: '$prefix.$suffix', customLogger: customLogger);
  }
}
