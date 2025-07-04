import '../../zebra_printer.dart';
import 'get_setting_command.dart';

/// Command to get head latch status from the printer
class GetHeadStatusCommand extends GetSettingCommand {
  /// Constructor
  GetHeadStatusCommand(ZebraPrinter printer) : super(printer, 'head.latch');
  
  @override
  String get operationName => 'Get Head Status';
} 