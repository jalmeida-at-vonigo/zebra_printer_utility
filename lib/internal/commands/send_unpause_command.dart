import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to send unpause command to the printer
class SendUnpauseCommand extends SendCommandCommand {
  /// Constructor
  SendUnpauseCommand(ZebraPrinter printer) : super(printer, '! U1 setvar "device.pause" "false"');
  
  @override
  String get operationName => 'Send Unpause Command';
} 