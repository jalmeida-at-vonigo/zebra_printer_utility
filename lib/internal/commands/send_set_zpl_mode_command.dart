import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to set printer to ZPL mode
class SendSetZplModeCommand extends SendCommandCommand {
  /// Constructor
  SendSetZplModeCommand(ZebraPrinter printer) : super(printer, '! U1 setvar "device.languages" "zpl"\r\n');
  
  @override
  String get operationName => 'Send Set ZPL Mode Command';
} 