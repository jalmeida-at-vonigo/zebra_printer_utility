import '../../zebra_printer.dart';
import 'get_setting_command.dart';

/// Command to get host status from the printer
class GetHostStatusCommand extends GetSettingCommand {
  /// Constructor
  GetHostStatusCommand(ZebraPrinter printer) : super(printer, 'device.host_status');
  
  @override
  String get operationName => 'Get Host Status';
} 