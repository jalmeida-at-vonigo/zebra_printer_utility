import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to send CPCL clear errors command to the printer
class SendCpclClearErrorsCommand extends SendCommandCommand {
  /// Constructor
  SendCpclClearErrorsCommand(ZebraPrinter printer) : super(printer, '! U1 setvar "alerts.clear" "ALL"\r\n');
  
  @override
  String get operationName => 'Send CPCL Clear Errors Command';
} 