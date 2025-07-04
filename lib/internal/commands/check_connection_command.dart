import '../../models/result.dart';
import 'printer_command.dart';

/// Command to check if the printer is connected
class CheckConnectionCommand extends PrinterCommand<bool> {
  /// Constructor
  CheckConnectionCommand(super.printer);
  
  @override
  String get operationName => 'Check Connection';
  
  @override
  Future<Result<bool>> execute() async {
    try {
      logger.debug('Checking printer connection');
      final isConnected = await printer.isPrinterConnected();
      logger.debug('Connection status: $isConnected');
      return Result.success(isConnected);
    } catch (e) {
      logger.error('Failed to check connection', e);
      return Result.error('Failed to check connection: $e');
    }
  }
} 