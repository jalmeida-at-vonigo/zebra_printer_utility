import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to send CPCL clear buffer command to the printer
class SendCpclClearBufferCommand extends SendCommandCommand {
  /// Constructor
  SendCpclClearBufferCommand(ZebraPrinter printer) : super(printer, '\x18'); // CAN character
  
  @override
  String get operationName => 'Send CPCL Clear Buffer Command';
} 