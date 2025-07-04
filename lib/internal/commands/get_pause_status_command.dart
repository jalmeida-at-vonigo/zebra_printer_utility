import '../../zebra_printer.dart';
import 'get_setting_command.dart';

/// Command to get pause status from the printer
class GetPauseStatusCommand extends GetSettingCommand {
  /// Constructor
  GetPauseStatusCommand(ZebraPrinter printer) : super(printer, 'device.pause');
  
  @override
  String get operationName => 'Get Pause Status';
} 