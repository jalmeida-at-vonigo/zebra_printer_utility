import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to send ZPL clear buffer command to the printer
class SendZplClearBufferCommand extends SendCommandCommand {
  /// Constructor
  SendZplClearBufferCommand(ZebraPrinter printer) : super(printer, '\x18'); // CAN character
  
  @override
  String get operationName => 'Send ZPL Clear Buffer Command';
} 