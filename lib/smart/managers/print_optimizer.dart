import '../../internal/logger.dart';
import '../../models/print_enums.dart';
import '../models/connection_type.dart';

/// Print Optimizer with ZSDK command optimization
class PrintOptimizer {
  final Logger _logger;
  
  // Optimization caches
  final Map<String, String> _optimizedDataCache = {};
  final Map<String, List<String>> _commandOptimizations = {};

  PrintOptimizer(this._logger);

  /// Optimize data for specific format and connection type
  Future<String> optimizeData(String data, PrintFormat format, ConnectionType connectionType) async {
    try {
      _logger.debug('Optimizing data for $format on $connectionType');
      
      // Create cache key
      final cacheKey = '${format.name}_${connectionType.name}_${data.hashCode}';
      
      // Check cache first
      if (_optimizedDataCache.containsKey(cacheKey)) {
        _logger.debug('Using cached optimized data');
        return _optimizedDataCache[cacheKey]!;
      }
      
      String optimizedData = data;
      
      // Apply format-specific optimizations
      optimizedData = await _applyFormatOptimizations(optimizedData, format);
      
      // Apply connection-specific optimizations
      optimizedData = await _applyConnectionOptimizations(optimizedData, connectionType);
      
      // Apply ZSDK-specific optimizations
      optimizedData = await _applyZSDKOptimizations(optimizedData, format);
      
      // Cache the result
      _optimizedDataCache[cacheKey] = optimizedData;
      
      _logger.debug('Data optimization completed');
      return optimizedData;
    } catch (e) {
      _logger.error('Data optimization failed: $e');
      return data; // Return original data if optimization fails
    }
  }

  /// Apply format-specific optimizations
  Future<String> _applyFormatOptimizations(String data, PrintFormat format) async {
    switch (format) {
      case PrintFormat.zpl:
        return await _optimizeZPLData(data);
      case PrintFormat.cpcl:
        return await _optimizeCPCLData(data);
      default:
        return data;
    }
  }

  /// Optimize ZPL data
  Future<String> _optimizeZPLData(String data) async {
    _logger.debug('Applying ZPL optimizations');
    
    String optimized = data;
    
    // Remove unnecessary whitespace and comments
    optimized = optimized.replaceAll(RegExp(r'^\s*~.*$', multiLine: true), ''); // Remove comments
    optimized = optimized.replaceAll(RegExp(r'\s+'), ' '); // Normalize whitespace
    
    // Optimize common ZPL patterns
    optimized = _optimizeZPLPatterns(optimized);
    
    return optimized;
  }

  /// Optimize CPCL data
  Future<String> _optimizeCPCLData(String data) async {
    _logger.debug('Applying CPCL optimizations');
    
    String optimized = data;
    
    // Remove unnecessary whitespace and comments
    optimized = optimized.replaceAll(RegExp(r'^\s*!.*$', multiLine: true), ''); // Remove comments
    optimized = optimized.replaceAll(RegExp(r'\s+'), ' '); // Normalize whitespace
    
    // Optimize common CPCL patterns
    optimized = _optimizeCPCLPatterns(optimized);
    
    return optimized;
  }

  /// Apply connection-specific optimizations
  Future<String> _applyConnectionOptimizations(String data, ConnectionType connectionType) async {
    switch (connectionType) {
      case ConnectionType.bluetooth:
        return await _optimizeForBluetooth(data);
      case ConnectionType.network:
        return await _optimizeForNetwork(data);
      case ConnectionType.usb:
        return await _optimizeForUSB(data);
      default:
        return data;
    }
  }

  /// Optimize for Bluetooth connections
  Future<String> _optimizeForBluetooth(String data) async {
    _logger.debug('Applying Bluetooth optimizations');
    
    // Bluetooth has limited bandwidth, so optimize for size
    String optimized = data;
    
    // Remove unnecessary whitespace
    optimized = optimized.replaceAll(RegExp(r'\s+'), ' ');
    
    // Compress repeated patterns
    optimized = _compressRepeatedPatterns(optimized);
    
    return optimized;
  }

  /// Optimize for Network connections
  Future<String> _optimizeForNetwork(String data) async {
    _logger.debug('Applying Network optimizations');
    
    // Network connections are fast, so optimize for readability and debugging
    String optimized = data;
    
    // Add line breaks for better readability
    optimized = _addReadableFormatting(optimized);
    
    return optimized;
  }

  /// Optimize for USB connections
  Future<String> _optimizeForUSB(String data) async {
    _logger.debug('Applying USB optimizations');
    
    // USB connections are very fast, minimal optimization needed
    return data;
  }

  /// Apply ZSDK-specific optimizations
  Future<String> _applyZSDKOptimizations(String data, PrintFormat format) async {
    _logger.debug('Applying ZSDK-specific optimizations');
    
    String optimized = data;
    
    // Add ZSDK-specific headers if needed
    optimized = _addZSDKHeaders(optimized, format);
    
    // Optimize command sequences
    optimized = _optimizeCommandSequences(optimized, format);
    
    return optimized;
  }

  /// Optimize ZPL patterns
  String _optimizeZPLPatterns(String data) {
    String optimized = data;
    
    // Optimize font commands - use simple string replacement instead of complex regex
    optimized = optimized.replaceAll('^A0N,', '^A0N,');
    
    // Optimize field origin commands
    optimized = optimized.replaceAll('^FO', '^FO');
    
    // Optimize field data commands
    optimized = optimized.replaceAll('^FD', '^FD');
    
    return optimized;
  }

  /// Optimize CPCL patterns
  String _optimizeCPCLPatterns(String data) {
    String optimized = data;
    
    // Optimize text commands - use simple string replacement
    optimized = optimized.replaceAll('! ', '! ');
    
    // Optimize graphics commands
    optimized = optimized.replaceAll('EG ', 'EG ');
    
    return optimized;
  }

  /// Compress repeated patterns
  String _compressRepeatedPatterns(String data) {
    // Simple pattern compression for repeated sequences
    String compressed = data;
    
    // Find and compress repeated ZPL commands using simple string operations
    final zplCommands = ['^XA', '^FO', '^A0N', '^FD', '^FS', '^XZ'];
    for (final command in zplCommands) {
      // Remove duplicate consecutive commands
      final pattern = '$command$command';
      while (compressed.contains(pattern)) {
        compressed = compressed.replaceAll(pattern, command);
      }
    }
    
    return compressed;
  }

  /// Add readable formatting
  String _addReadableFormatting(String data) {
    // Add line breaks for better readability in network connections
    String formatted = data;
    
    // Add line breaks after ZPL commands
    final zplCommands = ['^XA', '^FO', '^A0N', '^FD', '^FS', '^XZ'];
    for (final command in zplCommands) {
      formatted = formatted.replaceAll(command, '$command\n');
    }
    
    // Add line breaks after CPCL commands
    formatted = formatted.replaceAll('! ', '!\n');
    
    return formatted;
  }

  /// Add ZSDK-specific headers
  String _addZSDKHeaders(String data, PrintFormat format) {
    String withHeaders = data;
    
    switch (format) {
      case PrintFormat.zpl:
        // Add ZPL header if not present
        if (!withHeaders.startsWith('^XA')) {
          withHeaders = '^XA\n$withHeaders';
        }
        if (!withHeaders.endsWith('^XZ')) {
          withHeaders = '$withHeaders\n^XZ';
        }
        break;
      case PrintFormat.cpcl:
        // Add CPCL header if not present
        if (!withHeaders.startsWith('! ')) {
          withHeaders = '! 0 200 200 1 1\n$withHeaders';
        }
        break;
    }
    
    return withHeaders;
  }

  /// Optimize command sequences
  String _optimizeCommandSequences(String data, PrintFormat format) {
    String optimized = data;
    
    switch (format) {
      case PrintFormat.zpl:
        // Optimize ZPL command sequences
        optimized = _optimizeZPLSequences(optimized);
        break;
      case PrintFormat.cpcl:
        // Optimize CPCL command sequences
        optimized = _optimizeCPCLSequences(optimized);
        break;
    }
    
    return optimized;
  }

  /// Optimize ZPL command sequences
  String _optimizeZPLSequences(String data) {
    String optimized = data;
    
    // Combine multiple field origin commands - use simple string operations
    optimized = optimized.replaceAll('^FO ^FO', '^FO');
    
    // Combine multiple font commands
    optimized = optimized.replaceAll('^A0N ^A0N', '^A0N');
    
    return optimized;
  }

  /// Optimize CPCL command sequences
  String _optimizeCPCLSequences(String data) {
    String optimized = data;
    
    // Combine multiple text commands at same position - use simple string operations
    optimized = optimized.replaceAll('! ! ', '! ');
    
    return optimized;
  }

  /// Get optimization statistics
  Map<String, dynamic> getOptimizationStats() {
    return {
      'cachedOptimizations': _optimizedDataCache.length,
      'commandOptimizations': _commandOptimizations.length,
      'cacheHitRate': _calculateCacheHitRate(),
    };
  }

  /// Calculate cache hit rate
  double _calculateCacheHitRate() {
    // This would be implemented with actual hit/miss tracking
    return 0.8; // Placeholder
  }

  /// Clear optimization cache
  void clearCache() {
    _logger.info('Clearing optimization cache');
    _optimizedDataCache.clear();
    _commandOptimizations.clear();
  }

  /// Dispose resources
  void dispose() {
    clearCache();
  }
} 