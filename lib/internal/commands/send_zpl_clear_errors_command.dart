import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to send ZPL clear errors command to the printer
class SendZplClearErrorsCommand extends SendCommandCommand {
  /// Constructor
  SendZplClearErrorsCommand(ZebraPrinter printer) : super(printer, '~JA');
  
  @override
  String get operationName => 'Send ZPL Clear Errors Command';
} 