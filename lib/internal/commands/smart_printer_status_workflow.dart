import '../../models/result.dart';
import '../../models/print_enums.dart';
import '../../zebra_sgd_commands.dart';
import 'command_factory.dart';
import 'printer_command.dart';

/// Smart printer status workflow that orchestrates atomic commands
/// Uses language-specific commands based on the expected print format
class SmartPrinterStatusWorkflow extends PrinterCommand<Map<String, dynamic>> {
  /// The print data to analyze for language detection
  final String? printData;

  /// Constructor
  SmartPrinterStatusWorkflow(super.printer, {this.printData});
  
  @override
  String get operationName => 'Smart Printer Status Workflow';
  
  @override
  Future<Result<Map<String, dynamic>>> execute() async {
    try {
      logger.debug('Starting smart printer status workflow');
      
      // Step 1: Detect expected print language from data
      final expectedLanguage = _detectExpectedLanguage();
      logger.debug('Expected print language: $expectedLanguage');

      // Step 2: Get printer language (pre-print check)
      final languageResult = await CommandFactory.createGetPrinterLanguageCommand(printer).execute();
      if (!languageResult.success) {
        logger.error('Failed to get printer language: ${languageResult.error?.message}');
        return Result.error('Failed to get printer language: ${languageResult.error?.message}');
      }
      
      final currentLanguage = languageResult.data!;
      logger.debug('Current printer language: $currentLanguage');
      
      // Step 3: Get raw printer status
      final statusResult = await CommandFactory.createGetRawPrinterStatusCommand(printer).execute();
      if (!statusResult.success) {
        logger.error('Failed to get raw printer status: ${statusResult.error?.message}');
        return Result.error('Failed to get raw printer status: ${statusResult.error?.message}');
      }
      
      final rawStatus = statusResult.data!;
      logger.debug('Raw printer status: $rawStatus');
      
      // Step 4: Get language-specific additional settings
      final additionalSettings =
          await _getLanguageSpecificSettings(expectedLanguage);
      
      // Step 5: Build comprehensive status with analysis
      final comprehensiveStatus = await _buildComprehensiveStatus(
        expectedLanguage: expectedLanguage,
        currentLanguage: currentLanguage,
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
  
  /// Detect expected print language from data
  PrintFormat? _detectExpectedLanguage() {
    if (printData == null || printData!.isEmpty) {
      logger.debug('No print data provided, cannot detect language');
      return null;
    }

    return ZebraSGDCommands.detectDataLanguage(printData!);
  }

  /// Get language-specific settings using appropriate commands
  Future<Map<String, dynamic>> _getLanguageSpecificSettings(
      PrintFormat? expectedLanguage) async {
    final settings = <String, dynamic>{};
    
    if (expectedLanguage == null) {
      logger.debug(
          'No expected language detected, skipping language-specific settings');
      return settings;
    }
    
    try {
      // Safety check: Verify printer is in correct mode before sending language-specific commands
      final currentLanguageResult =
          await CommandFactory.createGetPrinterLanguageCommand(printer)
              .execute();
      if (currentLanguageResult.success && currentLanguageResult.data != null) {
        final currentLanguage = currentLanguageResult.data!.toLowerCase();
        bool languageMatches = false;

        switch (expectedLanguage) {
          case PrintFormat.zpl:
            languageMatches = currentLanguage.contains('zpl');
            break;
          case PrintFormat.cpcl:
            languageMatches = currentLanguage.contains('cpcl') ||
                currentLanguage.contains('line_print');
            break;
        }

        if (!languageMatches) {
          logger.warning(
              'Printer not in correct mode for ${expectedLanguage.name} commands. Current: $currentLanguage');
          return settings; // Skip language-specific commands if mode doesn't match
        }
      }

      switch (expectedLanguage) {
        case PrintFormat.zpl:
          logger.debug('Using ZPL-specific commands for status check');
          // ZPL-specific status checks
          final alertsResult = await CommandFactory.createGetSettingCommand(
                  printer, 'alerts.status')
              .execute();
          if (alertsResult.success && alertsResult.data != null) {
            settings['alerts'] = alertsResult.data;
          }
          break;
          
        case PrintFormat.cpcl:
          logger.debug('Using CPCL-specific commands for status check');
          // CPCL-specific status checks
          final alertsResult = await CommandFactory.createGetSettingCommand(
                  printer, 'alerts.status')
              .execute();
          if (alertsResult.success && alertsResult.data != null) {
            settings['alerts'] = alertsResult.data;
          }
          break;
      }
    } catch (e) {
      logger.warning('Failed to get language-specific settings: $e');
    }
    
    return settings;
  }
  
  /// Build comprehensive status with analysis
  Future<Map<String, dynamic>> _buildComprehensiveStatus({
    required PrintFormat? expectedLanguage,
    required String currentLanguage,
    required Map<String, dynamic> rawStatus,
    required Map<String, dynamic> additionalSettings,
  }) async {
    final status = <String, dynamic>{
      'expectedLanguage': expectedLanguage?.name,
      'currentLanguage': currentLanguage,
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
    
    // Check language compatibility
    if (expectedLanguage != null) {
      final languageMatches =
          _checkLanguageCompatibility(expectedLanguage, currentLanguage);
      if (!languageMatches) {
        blockingIssues.add('Language Mismatch');
        recommendations
            .add('Set printer to ${expectedLanguage.name.toUpperCase()} mode');
      }
    }
    
    // Check language-specific additional settings
    if (expectedLanguage != null) {
      await _checkLanguageSpecificIssues(expectedLanguage, additionalSettings,
          blockingIssues, recommendations);
    }
    
    // Determine if printer can print
    final canPrint = blockingIssues.isEmpty && (rawStatus['isReadyToPrint'] == true);
    
    status['analysis'] = {
      'canPrint': canPrint,
      'blockingIssues': blockingIssues,
      'recommendations': recommendations,
      'issueCount': blockingIssues.length,
      'languageCompatible': expectedLanguage == null ||
          _checkLanguageCompatibility(expectedLanguage, currentLanguage),
    };
    
    return status;
  }
  
  /// Check if current language is compatible with expected language
  bool _checkLanguageCompatibility(
      PrintFormat expectedLanguage, String currentLanguage) {
    switch (expectedLanguage) {
      case PrintFormat.zpl:
        return currentLanguage.toLowerCase().contains('zpl');
      case PrintFormat.cpcl:
        return currentLanguage.toLowerCase().contains('cpcl') ||
            currentLanguage.toLowerCase().contains('line_print');
    }
  }

  /// Check language-specific issues
  Future<void> _checkLanguageSpecificIssues(
    PrintFormat expectedLanguage,
    Map<String, dynamic> additionalSettings,
    List<String> blockingIssues,
    List<String> recommendations,
  ) async {
    final alerts = additionalSettings['alerts'];
    if (alerts != null) {
      final alertsStr = alerts.toString().toLowerCase();

      switch (expectedLanguage) {
        case PrintFormat.zpl:
          if (alertsStr.contains('head_cold')) {
            blockingIssues.add('Head Too Cold');
            recommendations.add('Wait for the print head to warm up');
          }
          if (alertsStr.contains('head_hot')) {
            blockingIssues.add('Head Too Hot');
            recommendations.add('Wait for the print head to cool down');
          }
          break;

        case PrintFormat.cpcl:
          if (alertsStr.contains('head_cold')) {
            blockingIssues.add('Head Too Cold');
            recommendations.add('Wait for the print head to warm up');
          }
          if (alertsStr.contains('head_hot')) {
            blockingIssues.add('Head Too Hot');
            recommendations.add('Wait for the print head to cool down');
          }
          break;
      }
    }
  }
} 