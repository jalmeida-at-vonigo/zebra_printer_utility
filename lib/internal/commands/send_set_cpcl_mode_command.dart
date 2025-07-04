import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to set printer to CPCL mode
class SendSetCpclModeCommand extends SendCommandCommand {
  /// Constructor
  SendSetCpclModeCommand(ZebraPrinter printer) : super(printer, '! U1 setvar "device.languages" "line_print"\r\n');
  
  @override
  String get operationName => 'Send Set CPCL Mode Command';
} 