import '../../models/result.dart';
import '../../zebra_sgd_commands.dart';
import 'printer_command.dart';

/// Command to get printer language
class GetPrinterLanguageCommand extends PrinterCommand<String> {
  GetPrinterLanguageCommand(super.printer);
  
  @override
  String get operationName => 'Get Printer Language';
  
  @override
  Future<Result<String>> execute() async {
    logger.debug('Getting printer language');
    
    // ZebraPrinter method is exception-free and already bridged
    final result = await printer.getSetting('device.languages');

    if (result.success) {
      final value = result.data;
      if (value != null && value.isNotEmpty) {
        final languages = ZebraSGDCommands.parseResponse(value);
        logger.debug('Printer languages: $languages');

        if (languages != null) {
          // Parse the language string to determine primary language
          final language = _parseLanguage(languages);
          logger.debug('Detected primary language: $language');

          return Result.success(language);
        }
      }
    } else {
      // Propagate ZebraPrinter error, preserve context
      return Result.errorFromResult(result, 'Language retrieval failed');
    }
    
    logger.debug('Could not determine printer language, defaulting to ZPL');
    return Result.success('ZPL');
  }

  /// Parse language string to determine primary language
  String _parseLanguage(String languages) {
    final lowerLanguages = languages.toLowerCase();
    
    if (lowerLanguages.contains('zpl')) {
      return 'ZPL';
    } else if (lowerLanguages.contains('cpcl') || lowerLanguages.contains('line_print')) {
      return 'CPCL';
    } else {
      // Default to ZPL if unknown
      return 'ZPL';
    }
  }
} 