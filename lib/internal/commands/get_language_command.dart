import '../../models/print_enums.dart';
import '../../models/result.dart';
import '../parser_util.dart';
import 'printer_command.dart';

/// Command to get printer language setting
/// Returns PrintFormat enum based on raw SGD response parsing
class GetLanguageCommand extends PrinterCommand<PrintFormat?> {
  /// Constructor
  GetLanguageCommand(super.printer);
  
  @override
  String get operationName => 'Get Printer Language';
  
  @override
  Future<Result<PrintFormat?>> execute() async {
    logger.debug('Getting printer language via SGD');

    // Get raw SGD response from iOS ZSDK
    final result = await printer.getSetting('device.languages');

    if (result.success) {
      final value = result.data;
      if (value != null && value.isNotEmpty) {
        // Parse the SGD response (handles formats like '"device.languages" : "zpl"')
        final parsedValue = ParserUtil.parseResponse(value);
        logger.debug('SGD response: $value -> parsed: $parsedValue');

        if (parsedValue != null) {
          // Convert to PrintFormat enum
          final format = _stringToLanguageEnum(parsedValue);
          logger.debug('Detected language format: $format');

          // If we successfully parsed a known format, return it
          if (format != null) {
            return Result.success(format);
          }
          // If format is null (unknown), fall through to default
        }
      }
    } else {
      logger.debug('Language retrieval failed: ${result.error?.message}');
      // Propagate error with context
      return Result.errorFromResult(result, 'Language retrieval failed');
    }

    logger.debug('Could not determine printer language, defaulting to ZPL');
    return Result.success(PrintFormat.zpl);
  }

  /// Convert string language to PrintFormat enum
  /// Handles various language string formats from SGD responses
  /// Specifically designed for iOS ZSDK SGD responses for device.languages
  static PrintFormat? _stringToLanguageEnum(String language) {
    final lower = language.toLowerCase();

    // Check for ZPL indicators (handles responses like "zpl" or "zpl,line_print")
    if (lower.contains('zpl')) {
      return PrintFormat.zpl;
    }

    // Check for CPCL indicators (handles "line_print", "cpcl", or "cpcl mode")
    if (lower.contains('line_print') || lower.contains('cpcl')) {
      return PrintFormat.cpcl;
    }

    // Unknown format
    return null;
  }
} 