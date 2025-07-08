import '../../models/result.dart';
import 'command_factory.dart';
import 'printer_command.dart';

/// Smart printer status workflow that orchestrates atomic commands
class SmartPrinterStatusWorkflow extends PrinterCommand<Map<String, dynamic>> {
  SmartPrinterStatusWorkflow(super.printer);
  
  @override
  String get operationName => 'Smart Printer Status Workflow';
  
  @override
  Future<Result<Map<String, dynamic>>> execute() async {
    try {
      logger.debug('Starting smart printer status workflow');
      
      // Step 1: Get printer language (pre-print check)
      final languageResult = await CommandFactory.createGetPrinterLanguageCommand(printer).execute();
      if (!languageResult.success) {
        logger.error('Failed to get printer language: ${languageResult.error?.message}');
        return Result.error('Failed to get printer language: ${languageResult.error?.message}');
      }
      
      final language = languageResult.data!;
      logger.debug('Detected printer language: $language');
      
      // Step 2: Get raw printer status
      final statusResult = await CommandFactory.createGetRawPrinterStatusCommand(printer).execute();
      if (!statusResult.success) {
        logger.error('Failed to get raw printer status: ${statusResult.error?.message}');
        return Result.error('Failed to get raw printer status: ${statusResult.error?.message}');
      }
      
      final rawStatus = statusResult.data!;
      logger.debug('Raw printer status: $rawStatus');
      
      // Step 3: Get additional settings if needed (SGD-based)
      final additionalSettings = await _getAdditionalSettings();
      
      // Step 4: Build comprehensive status with analysis
      final comprehensiveStatus = await _buildComprehensiveStatus(
        language: language,
        rawStatus: rawStatus,
        additionalSettings: additionalSettings,
      );
      
      logger.debug('Smart printer status workflow completed successfully');
      return Result.success(comprehensiveStatus);
    } catch (e) {
      logger.error('Smart printer status workflow failed', e);
      return Result.error('Smart printer status workflow failed: $e');
    }
  }
  
  /// Get additional settings using SGD protocol
  Future<Map<String, dynamic>> _getAdditionalSettings() async {
    final settings = <String, dynamic>{};
    
    try {
      // Get alerts status
      final alertsResult = await CommandFactory.createGetSettingCommand(printer, 'alerts.status').execute();
      if (alertsResult.success && alertsResult.data != null) {
        settings['alerts'] = alertsResult.data;
      }
      
      // Get media type
      final mediaResult = await CommandFactory.createGetSettingCommand(printer, 'media.type').execute();
      if (mediaResult.success && mediaResult.data != null) {
        settings['mediaType'] = mediaResult.data;
      }
      
      // Get print tone
      final toneResult = await CommandFactory.createGetSettingCommand(printer, 'print.tone').execute();
      if (toneResult.success && toneResult.data != null) {
        settings['printTone'] = toneResult.data;
      }
    } catch (e) {
      logger.warning('Failed to get some additional settings: $e');
    }
    
    return settings;
  }
  
  /// Build comprehensive status with analysis
  Future<Map<String, dynamic>> _buildComprehensiveStatus({
    required String language,
    required Map<String, dynamic> rawStatus,
    required Map<String, dynamic> additionalSettings,
  }) async {
    final status = <String, dynamic>{
      'language': language,
      'basicStatus': rawStatus,
      'additionalSettings': additionalSettings,
      'analysis': <String, dynamic>{},
    };
    
    // Analyze status and identify issues
    final blockingIssues = <String>[];
    final recommendations = <String>[];
    
    // Check basic status fields
    if (rawStatus['isHeadOpen'] == true) {
      blockingIssues.add('Head Open');
      recommendations.add('Close the printer head');
    }
    
    if (rawStatus['isPaperOut'] == true) {
      blockingIssues.add('Out of Paper');
      recommendations.add('Load paper into the printer');
    }
    
    if (rawStatus['isPaused'] == true) {
      blockingIssues.add('Printer Paused');
      recommendations.add('Resume the printer');
    }
    
    if (rawStatus['isRibbonOut'] == true) {
      blockingIssues.add('Out of Ribbon');
      recommendations.add('Replace the ribbon');
    }
    
    // Check additional settings for more issues
    final alerts = additionalSettings['alerts'];
    if (alerts != null && alerts.toString().contains('head_cold')) {
      blockingIssues.add('Head Too Cold');
      recommendations.add('Wait for the print head to warm up');
    }
    
    if (alerts != null && alerts.toString().contains('head_hot')) {
      blockingIssues.add('Head Too Hot');
      recommendations.add('Wait for the print head to cool down');
    }
    
    // Determine if printer can print
    final canPrint = blockingIssues.isEmpty && (rawStatus['isReadyToPrint'] == true);
    
    status['analysis'] = {
      'canPrint': canPrint,
      'blockingIssues': blockingIssues,
      'recommendations': recommendations,
      'issueCount': blockingIssues.length,
    };
    
    return status;
  }
} 