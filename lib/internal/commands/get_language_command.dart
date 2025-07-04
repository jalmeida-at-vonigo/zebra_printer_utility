import '../../zebra_printer.dart';
import 'get_setting_command.dart';

/// Command to get printer language setting
class GetLanguageCommand extends GetSettingCommand {
  /// Constructor
  GetLanguageCommand(ZebraPrinter printer) : super(printer, 'device.languages');
  
  @override
  String get operationName => 'Get Printer Language';
} 