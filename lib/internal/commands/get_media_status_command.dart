import '../../zebra_printer.dart';
import 'get_setting_command.dart';

/// Command to get media status from the printer
class GetMediaStatusCommand extends GetSettingCommand {
  /// Constructor
  GetMediaStatusCommand(ZebraPrinter printer) : super(printer, 'media.status');
  
  @override
  String get operationName => 'Get Media Status';
} 