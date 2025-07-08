import '../../models/result.dart';
import 'printer_command.dart';

/// Command to send any command to the printer
class SendCommandCommand extends PrinterCommand<void> {
  /// The command to send
  final String command;
  
  /// Constructor
  SendCommandCommand(super.printer, this.command);
  
  @override
  String get operationName => 'Send Command: $command';
  
  @override
  Future<Result<void>> execute() async {
    try {
      logger.debug('Sending command: $command');
      final result = await printer.print(data: command);
      if (result.success) {
        logger.debug('Command sent successfully');
        return Result.success();
      } else {
        logger.error('Failed to send command: ${result.error?.message}');
        return result;
      }
    } catch (e) {
      logger.error('Failed to send command: $command', e);
      return Result.error('Failed to send command: $e');
    }
  }
} 