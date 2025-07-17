import '../../models/result.dart';
import '../../zebra_sgd_commands.dart';
import 'printer_command.dart';

/// Command to get a printer setting using SGD protocol
class GetSettingCommand extends PrinterCommand<String?> {
  /// Constructor
  GetSettingCommand(super.printer, this.setting);
  
  /// The setting to retrieve
  final String setting;
  
  @override
  String get operationName => 'Get Setting: $setting';
  
  @override
  Future<Result<String?>> execute() async {
    logger.debug('Getting setting: $setting');
    
    // ZebraPrinter method is exception-free and already bridged
    final result = await printer.getSetting(setting);

    if (result.success) {
      // Add business logic (SGD response parsing)
      final parsed = result.data != null
          ? ZebraSGDCommands.parseResponse(result.data!)
          : null;
      logger.debug('Setting $setting = $parsed');
      return Result.success(parsed);
    } else {
      // Propagate ZebraPrinter error, preserve context
      return Result.errorFromResult(result, 'Setting retrieval failed');
    }
  }
} 