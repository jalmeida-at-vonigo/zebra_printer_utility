import '../../models/result.dart';
import 'printer_command.dart';

/// Command to get raw printer status (atomic operation)
class GetRawPrinterStatusCommand extends PrinterCommand<Map<String, dynamic>> {
  GetRawPrinterStatusCommand(super.printer);
  
  @override
  String get operationName => 'Get Raw Printer Status';
  
  @override
  Future<Result<Map<String, dynamic>>> execute() async {
    try {
      logger.debug('Getting raw printer status');
      
      final result = await printer.channel.invokeMethod('getPrinterStatus');
      
      if (result is Map) {
        // Convert to Map<String, dynamic> if needed
        final Map<String, dynamic> statusMap = Map<String, dynamic>.from(result);
        logger.debug('Raw printer status retrieved successfully');
        return Result.success(statusMap);
      } else {
        logger.error('Unexpected response type for raw status: ${result.runtimeType}');
        return Result.error('Invalid response format for raw status');
      }
    } catch (e) {
      logger.error('Failed to get raw printer status', e);
      return Result.error('Failed to get raw printer status: $e');
    }
  }
} 