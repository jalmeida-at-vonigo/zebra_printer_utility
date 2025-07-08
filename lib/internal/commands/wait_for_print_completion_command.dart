import '../../models/result.dart';
import 'printer_command.dart';

/// Command to wait for print completion with timeout
class WaitForPrintCompletionCommand extends PrinterCommand<bool> {
  /// Timeout in seconds
  final int timeoutSeconds;
  
  /// Constructor
  WaitForPrintCompletionCommand(super.printer, {this.timeoutSeconds = 30});
  
  @override
  String get operationName => 'Wait For Print Completion Command';

  @override
  Future<Result<bool>> execute() async {
    try {
      logger.debug('Waiting for print completion (timeout: ${timeoutSeconds}s)');
      
      final result = await printer.channel.invokeMethod('waitForPrintCompletion', {
        'timeout': timeoutSeconds,
      });
      
      if (result is bool) {
        logger.debug('Print completion result: $result');
        return Result.success(result);
      } else {
        throw Exception('Invalid response format for print completion');
      }
    } catch (e) {
      logger.error('Failed to wait for print completion', e);
      return Result.error('Failed to wait for print completion: $e');
    }
  }
} 