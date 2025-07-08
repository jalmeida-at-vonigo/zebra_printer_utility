import '../../models/result.dart';
import '../../zebra_sgd_commands.dart';
import 'printer_command.dart';

/// Smart waiting command that estimates print time based on data size and language
class SmartWaitForPrintCompletionCommand extends PrinterCommand<void> {
  /// The data to be printed
  final String printData;
  
  /// Maximum wait time in seconds
  final int maxWaitTimeSeconds;
  
  /// Constructor
  SmartWaitForPrintCompletionCommand(
    super.printer,
    this.printData,
    this.maxWaitTimeSeconds,
  );
  
  @override
  String get operationName => 'Smart Wait for Print Completion';
  
  @override
  Future<Result<void>> execute() async {
    try {
      logger.debug('Starting smart wait for print completion');
      
      // Step 1: Detect print language from data
      final language = _detectPrintLanguage(printData);
      logger.debug('Detected print language: $language');
      
      // Step 2: Calculate estimated print time
      final estimatedTime = _calculateEstimatedPrintTime(printData, language);
      logger.debug('Estimated print time: ${estimatedTime.inMilliseconds}ms');
      
      // Step 3: Wait for estimated time or max wait time, whichever is shorter
      final waitTime = estimatedTime.inMilliseconds < (maxWaitTimeSeconds * 1000)
          ? estimatedTime.inMilliseconds
          : maxWaitTimeSeconds * 1000;
      
      logger.debug('Waiting for ${waitTime}ms for print completion');
      await Future.delayed(Duration(milliseconds: waitTime));
      
      logger.debug('Smart wait for print completion completed');
      return Result.success();
    } catch (e) {
      logger.error('Smart wait for print completion failed', e);
      return Result.error('Smart wait for print completion failed: $e');
    }
  }
  
  /// Detect print language from data
  String _detectPrintLanguage(String data) {
    if (ZebraSGDCommands.isZPLData(data)) {
      return 'ZPL';
    } else if (ZebraSGDCommands.isCPCLData(data)) {
      return 'CPCL';
    } else {
      // Default to ZPL for unknown formats
      return 'ZPL';
    }
  }
  
  /// Calculate estimated print time based on data size and language
  Duration _calculateEstimatedPrintTime(String data, String language) {
    final dataSize = data.length;
    
    // Base time per character (in milliseconds)
    double baseTimePerChar;
    switch (language) {
      case 'ZPL':
        // ZPL is generally faster, ~0.1ms per character
        baseTimePerChar = 0.1;
        break;
      case 'CPCL':
        // CPCL is slower, ~0.2ms per character
        baseTimePerChar = 0.2;
        break;
      default:
        baseTimePerChar = 0.15;
    }
    
    // Calculate base time
    final baseTime = dataSize * baseTimePerChar;
    
    // Add overhead for printer processing
    const overhead = 1000.0; // 1 second overhead
    
    // Add time for mechanical operations (paper feed, etc.)
    const mechanicalTime = 2000.0; // 2 seconds for mechanical operations
    
    final totalTimeMs = baseTime + overhead + mechanicalTime;
    
    // Ensure minimum wait time
    const minWaitTime = 3000.0; // 3 seconds minimum
    final finalTimeMs = totalTimeMs < minWaitTime ? minWaitTime : totalTimeMs;
    
    return Duration(milliseconds: finalTimeMs.round());
  }
} 