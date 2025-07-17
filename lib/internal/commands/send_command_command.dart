import '../../models/result.dart';
import 'printer_command.dart';

/// Command to send any command to the printer
class SendCommandCommand extends PrinterCommand<void> {
  /// Constructor
  SendCommandCommand(super.printer, this.command);
  
  /// The command to send
  final String command;
  
  @override
  String get operationName => 'Send Command: $command';
  
  @override
  Future<Result<void>> execute() async {
    logger.debug('Sending command: $command');
    
    // ZebraPrinter.print is exception-free and already bridged
    final result = await printer.print(data: command);
    
    if (result.success) {
      logger.debug('Command sent successfully');
      return Result.success();
    } else {
      logger.error('Failed to send command: ${result.error?.message}');
      // Propagate ZebraPrinter error, don't re-bridge
      return Result.errorFromResult(result, 'Command send failed');
    }
  }
} 