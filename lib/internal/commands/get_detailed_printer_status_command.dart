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
    logger.debug('Getting detailed printer status');
    
    // ZebraPrinter method is exception-free and already bridged
    final result = await printer.getDetailedPrinterStatus();
    
    if (result.success) {
      // Add business logic (analysis and recommendations)
      final enhancedResult = _analyzeStatus(result.data!);
      return Result.success(enhancedResult);
    } else {
      // Propagate ZebraPrinter error, don't re-bridge
      return Result.errorFromResult(result, 'Detailed status check failed');
    }
  }
  
  /// Analyze status and provide recommendations
  Map<String, dynamic> _analyzeStatus(Map<String, dynamic> rawStatus) {
    final basicStatus = rawStatus['basicStatus'] as Map<String, dynamic>? ?? {};
    final alerts = rawStatus['alerts'] as String? ?? '';
    final mediaType = rawStatus['mediaType'] as String? ?? '';
    final printMode = rawStatus['printMode'] as String? ?? '';

    final blockingIssues = <String>[];
    final recommendations = <String>[];
    var canPrint = true;
    var statusDescription = 'Unknown status';

    // Check basic status issues
    final isReadyToPrint = basicStatus['isReadyToPrint'] == true;
    final isHeadOpen = basicStatus['isHeadOpen'] == true;
    final isPaperOut = basicStatus['isPaperOut'] == true;
    final isRibbonOut = basicStatus['isRibbonOut'] == true;
    final isPaused = basicStatus['isPaused'] == true;
    final isHeadCold = basicStatus['isHeadCold'] == true;
    final isHeadTooHot = basicStatus['isHeadTooHot'] == true;

    if (isHeadOpen) {
      blockingIssues.add('Printer head is open');
      recommendations.add('Close the printer head/lid and try again');
      canPrint = false;
    }

    if (isPaperOut) {
      blockingIssues.add('Out of paper/media');
      recommendations.add('Load paper/media and try again');
      canPrint = false;
    }

    if (isRibbonOut) {
      blockingIssues.add('Out of ribbon');
      recommendations.add('Replace ribbon and try again');
      canPrint = false;
    }

    if (isPaused) {
      blockingIssues.add('Printer is paused');
      recommendations.add('Press the pause button on the printer to resume');
      canPrint = false;
    }

    if (isHeadCold) {
      blockingIssues.add('Print head is cold');
      recommendations.add('Wait for print head to warm up');
      canPrint = false;
    }

    if (isHeadTooHot) {
      blockingIssues.add('Print head is too hot');
      recommendations.add('Wait for print head to cool down');
      canPrint = false;
    }

    // Generate status description
    if (isReadyToPrint && blockingIssues.isEmpty) {
      statusDescription = 'Ready to print';
      recommendations.add('Printer is ready to print');
    } else if (blockingIssues.isNotEmpty) {
      statusDescription = blockingIssues.join('; ');
    }

    return {
      'basicStatus': basicStatus,
      'alerts': alerts,
      'mediaType': mediaType,
      'printMode': printMode,
      'canPrint': canPrint,
      'blockingIssues': blockingIssues,
      'recommendations': recommendations,
      'statusDescription': statusDescription,
    };
  }
} 