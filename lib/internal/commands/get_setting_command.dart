import '../../models/result.dart';
import '../../zebra_sgd_commands.dart';
import 'printer_command.dart';

/// Command to get a printer setting using SGD protocol
class GetSettingCommand extends PrinterCommand<String?> {
  /// The setting to retrieve
  final String setting;
  
  /// Constructor
  GetSettingCommand(super.printer, this.setting);
  
  @override
  String get operationName => 'Get Setting: $setting';
  
  @override
  Future<Result<String?>> execute() async {
    try {
      logger.debug('Getting setting: $setting');
      final value = await printer.getSetting(setting);
      
      if (value != null && value.isNotEmpty) {
        final parsed = ZebraSGDCommands.parseResponse(value);
        logger.debug('Setting $setting = $parsed');
        return Result.success(parsed);
      }
      
      logger.debug('Setting $setting returned null or empty');
      return Result.success(null);
    } catch (e) {
      logger.error('Failed to get setting $setting', e);
      return Result.error('Failed to get setting $setting: $e');
    }
  }
} 