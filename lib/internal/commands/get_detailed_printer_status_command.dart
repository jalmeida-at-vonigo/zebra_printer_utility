import '../../models/result.dart';
import 'printer_command.dart';

/// Command to get detailed printer status with recommendations
class GetDetailedPrinterStatusCommand extends PrinterCommand<Map<String, dynamic>> {
  /// Constructor
  GetDetailedPrinterStatusCommand(super.printer);
  
  @override
  String get operationName => 'Get Detailed Printer Status Command';

  @override
  Future<Result<Map<String, dynamic>>> execute() async {
    try {
      logger.debug('Getting detailed printer status');
      
      final result = await printer.channel.invokeMethod('getDetailedPrinterStatus');
      
      if (result is Map) {
        // Convert to Map<String, dynamic> if needed
        final Map<String, dynamic> statusMap =
            Map<String, dynamic>.from(result);

        // Validate the response structure
        if (_isValidDetailedStatusResponse(statusMap)) {
          logger.debug('Detailed printer status retrieved successfully');
          return Result.success(statusMap);
        } else {
          logger
              .error('Invalid detailed status response structure: $statusMap');
          return Result.errorCode(
            ErrorCodes.statusResponseFormatError,
            formatArgs: ['detailed'],
          );
        }
      } else {
        logger.error(
            'Unexpected response type for detailed status: ${result.runtimeType}');
        return Result.errorCode(
          ErrorCodes.statusResponseFormatError,
          formatArgs: ['detailed'],
        );
      }
    } catch (e) {
      logger.error('Failed to get detailed printer status', e);
      
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
          ErrorCodes.detailedStatusCheckFailed,
          formatArgs: [e.toString()],
        );
      }
    }
  }

  /// Validate detailed status response structure
  bool _isValidDetailedStatusResponse(Map<String, dynamic> response) {
    // Check for required top-level keys
    final requiredKeys = [
      'basicStatus',
      'canPrint',
      'blockingIssues',
      'recommendations'
    ];
    for (final key in requiredKeys) {
      if (!response.containsKey(key)) {
        logger.debug('Missing required key in detailed status: $key');
        return false;
      }
    }

    // Check that basicStatus is a Map
    if (response['basicStatus'] is! Map<String, dynamic>) {
      logger.debug('basicStatus is not a Map: ${response['basicStatus']}');
      return false;
    }

    // Check that blockingIssues and recommendations are Lists
    if (response['blockingIssues'] is! List) {
      logger
          .debug('blockingIssues is not a List: ${response['blockingIssues']}');
      return false;
    }

    if (response['recommendations'] is! List) {
      logger.debug(
          'recommendations is not a List: ${response['recommendations']}');
      return false;
    }

    // Check that canPrint is a boolean
    if (response['canPrint'] is! bool) {
      logger.debug('canPrint is not a boolean: ${response['canPrint']}');
      return false;
    }
    
    return true;
  }
} 