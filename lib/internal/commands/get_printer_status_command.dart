import '../../models/result.dart';
import 'printer_command.dart';

/// Command to get printer status from the printer
class GetPrinterStatusCommand extends PrinterCommand<Map<String, dynamic>> {
  /// Constructor
  GetPrinterStatusCommand(super.printer);
  
  @override
  String get operationName => 'Get Printer Status Command';

  @override
  Future<Result<Map<String, dynamic>>> execute() async {
    try {
      logger.debug('Getting printer status');
      
      // Use the operation manager to call the native method
      final result = await printer.channel.invokeMethod('getPrinterStatus');
      
      if (result is Map) {
        // Convert to Map<String, dynamic> if needed
        final Map<String, dynamic> statusMap =
            Map<String, dynamic>.from(result);

        // Validate the response structure
        if (_isValidBasicStatusResponse(statusMap)) {
          logger.debug('Printer status retrieved successfully');
          return Result.success(statusMap);
        } else {
          logger.error('Invalid basic status response structure: $statusMap');
          return Result.errorCode(
            ErrorCodes.statusResponseFormatError,
            formatArgs: ['basic'],
          );
        }
      } else {
        logger.error(
            'Unexpected response type for basic status: ${result.runtimeType}');
        return Result.errorCode(
          ErrorCodes.statusResponseFormatError,
          formatArgs: ['basic'],
        );
      }
    } catch (e) {
      logger.error('Failed to get printer status', e);
      
      // Classify the error for better recovery
      if (e.toString().contains('timeout')) {
        return Result.errorCode(
          ErrorCodes.statusTimeoutError,
          formatArgs: [e.toString()],
        );
      } else if (e.toString().contains('connection') ||
          e.toString().contains('disconnect')) {
        return Result.errorCode(
          ErrorCodes.statusConnectionError,
          formatArgs: [e.toString()],
        );
      } else {
        return Result.errorCode(
          ErrorCodes.basicStatusCheckFailed,
          formatArgs: [e.toString()],
        );
      }
    }
  }

  /// Validate basic status response structure
  bool _isValidBasicStatusResponse(Map<String, dynamic> response) {
    // Check for required keys
    final requiredKeys = [
      'isReadyToPrint',
      'isHeadOpen',
      'isPaperOut',
      'isPaused',
      'isRibbonOut'
    ];
    for (final key in requiredKeys) {
      if (!response.containsKey(key)) {
        logger.debug('Missing required key in basic status: $key');
        return false;
      }
    }

    // Check that boolean values are actually booleans
    final booleanKeys = [
      'isReadyToPrint',
      'isHeadOpen',
      'isPaperOut',
      'isPaused',
      'isRibbonOut'
    ];
    for (final key in booleanKeys) {
      if (response[key] is! bool) {
        logger.debug('$key is not a boolean: ${response[key]}');
        return false;
      }
    }
    
    return true;
  }
} 