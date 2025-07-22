import '../internal/commands/command_factory.dart';
import '../internal/communication_policy.dart';
import '../internal/logger.dart';
import '../internal/parser_util.dart';
import '../zebra_printer.dart';
import 'readiness_options.dart';

/// Lazy printer readiness status that only calls commands when first accessed
class PrinterReadiness {

  /// Constructor
  PrinterReadiness({
    required ZebraPrinter printer,
    ReadinessOptions? options,
  })  : _printer = printer,
        _options = options {
    _communicationPolicy = CommunicationPolicy(printer);
  }
  final ZebraPrinter _printer;
  final Logger _logger = Logger.withPrefix('PrinterReadiness');
  
  /// Communication policy for connection assurance and command execution
  late final CommunicationPolicy _communicationPolicy;

  // Connection status
  bool? _isConnected;
  bool _connectionRead = false;

  // Media status
  String? _mediaStatus;
  bool? _hasMedia;
  bool _mediaRead = false;

  // Head status
  String? _headStatus;
  bool? _headClosed;
  bool _headRead = false;

  // Pause status
  String? _pauseStatus;
  bool? _isPaused;
  bool _pauseRead = false;

  // Host/Error status
  String? _hostStatus;
  List<String> _errors = [];
  bool _hostRead = false;

  // Language status
  String? _languageStatus;
  bool _languageRead = false;

  // Readiness options to control what gets read
  final ReadinessOptions? _options;

  /// Get connection status (lazy)
  Future<bool?> get isConnected async {
    return await ensureConnection();
  }

  /// Ensure connection status is checked and return the value
  Future<bool?> ensureConnection() async {
    if (!_connectionRead && (_options?.checkConnection ?? true)) {
      await _readConnectionStatus();
    }
    return _isConnected;
  }

  /// Whether connection status has been read
  bool get wasConnectionRead => _connectionRead;

  /// Get media status (lazy)
  Future<String?> get mediaStatus async {
    return await ensureMediaStatus();
  }

  /// Ensure media status is checked and return the value
  Future<String?> ensureMediaStatus() async {
    if (!_mediaRead && (_options?.checkMedia ?? true)) {
      await _readMediaStatus();
    }
    return _mediaStatus;
  }

  /// Whether media status has been read
  bool get wasMediaRead => _mediaRead;

  /// Get has media (lazy)
  Future<bool?> get hasMedia async {
    return await ensureHasMedia();
  }

  /// Ensure has media is checked and return the value
  Future<bool?> ensureHasMedia() async {
    if (!_mediaRead && (_options?.checkMedia ?? true)) {
      await _readMediaStatus();
    }
    return _hasMedia;
  }

  /// Get head status (lazy)
  Future<String?> get headStatus async {
    return await ensureHeadStatus();
  }

  /// Ensure head status is checked and return the value
  Future<String?> ensureHeadStatus() async {
    if (!_headRead && (_options?.checkHead ?? true)) {
      await _readHeadStatus();
    }
    return _headStatus;
  }

  /// Whether head status has been read
  bool get wasHeadRead => _headRead;

  /// Get head closed status (lazy)
  Future<bool?> get headClosed async {
    return await ensureHeadClosed();
  }

  /// Ensure head closed is checked and return the value
  Future<bool?> ensureHeadClosed() async {
    if (!_headRead && (_options?.checkHead ?? true)) {
      await _readHeadStatus();
    }
    return _headClosed;
  }

  /// Get pause status (lazy)
  Future<String?> get pauseStatus async {
    return await ensurePauseStatus();
  }

  /// Ensure pause status is checked and return the value
  Future<String?> ensurePauseStatus() async {
    if (!_pauseRead && (_options?.checkPause ?? true)) {
      await _readPauseStatus();
    }
    return _pauseStatus;
  }

  /// Whether pause status has been read
  bool get wasPauseRead => _pauseRead;

  /// Get is paused status (lazy)
  Future<bool?> get isPaused async {
    return await ensureIsPaused();
  }

  /// Ensure is paused is checked and return the value
  Future<bool?> ensureIsPaused() async {
    if (!_pauseRead && (_options?.checkPause ?? true)) {
      await _readPauseStatus();
    }
    return _isPaused;
  }

  /// Get host status (lazy)
  Future<String?> get hostStatus async {
    return await ensureHostStatus();
  }

  /// Ensure host status is checked and return the value
  Future<String?> ensureHostStatus() async {
    if (!_hostRead && (_options?.checkErrors ?? true)) {
      await _readHostStatus();
    }
    return _hostStatus;
  }

  /// Whether host status has been read
  bool get wasHostRead => _hostRead;

  /// Get errors (lazy)
  Future<List<String>> get errors async {
    return await ensureErrors();
  }

  /// Ensure errors are checked and return the value
  Future<List<String>> ensureErrors() async {
    if (!_hostRead && (_options?.checkErrors ?? true)) {
      await _readHostStatus();
    }
    return List.unmodifiable(_errors);
  }

  /// Get language status (lazy)
  Future<String?> get languageStatus async {
    return await ensureLanguageStatus();
  }

  /// Ensure language status is checked and return the value
  Future<String?> ensureLanguageStatus() async {
    if (!_languageRead && (_options?.checkLanguage ?? true)) {
      await _readLanguageStatus();
    }
    return _languageStatus;
  }

  /// Whether language status has been read
  bool get wasLanguageRead => _languageRead;

  /// Get overall readiness status (lazy)
  Future<bool> get isReady async {
    // Only read all statuses once, then use cached values
    await readAllStatuses();

    // Use cached values instead of triggering new reads
    if (_connectionRead && _isConnected == false) return false;
    if (_mediaRead && _hasMedia == false) return false;
    if (_headRead && _headClosed == false) return false;
    if (_pauseRead && _isPaused == true) return false;
    if (_hostRead && _errors.isNotEmpty) return false;

    return true;
  }

  /// Force read all statuses based on options
  Future<void> readAllStatuses() async {
    _logger.info('PrinterReadiness: Reading all statuses based on options');

    await ensureConnection();
    await ensureMediaStatus();
    await ensureHeadStatus();
    await ensurePauseStatus();
    await ensureHostStatus();
    await ensureLanguageStatus();
  }

  /// Set cached values (for use during prepare process)
  void setCachedConnection(bool connected) {
    _isConnected = connected;
    _connectionRead = true;
  }

  void setCachedMedia(String status, bool hasMedia) {
    _mediaStatus = status;
    _hasMedia = hasMedia;
    _mediaRead = true;
  }

  void setCachedHead(String status, bool headClosed) {
    _headStatus = status;
    _headClosed = headClosed;
    _headRead = true;
  }

  void setCachedPause(String status, bool isPaused) {
    _pauseStatus = status;
    _isPaused = isPaused;
    _pauseRead = true;
  }

  void setCachedHost(String status, List<String> errors) {
    _hostStatus = status;
    _errors = List.from(errors);
    _hostRead = true;
  }

  void setCachedLanguage(String status) {
    _languageStatus = status;
    _languageRead = true;
  }

  // Private methods to read statuses
  Future<void> _readConnectionStatus() async {
    if (_connectionRead) {
      _logger.debug(
          'PrinterReadiness: Connection status already read, skipping duplicate read');
      return;
    }

    _logger.info('PrinterReadiness: Reading connection status');
    _logger.debug(
        'PrinterReadiness: Connection status read triggered by ensureConnection() call');
    
    try {
      // Use centralized connection assurance
      final result = await _communicationPolicy.getConnectionStatus();
      _isConnected = result.data ?? false;
      _connectionRead = true;
      _logger.info('PrinterReadiness: Connection status read: $_isConnected');
    } catch (e) {
      _logger.error('PrinterReadiness: Error reading connection status: $e');
      _isConnected = false;
      _connectionRead = true;
    }
  }

  Future<void> _readMediaStatus() async {
    if (_mediaRead) {
      _logger.debug(
          'PrinterReadiness: Media status already read, skipping duplicate read');
      return;
    }

    _logger.info('PrinterReadiness: Reading media status');
    _logger.debug(
        'PrinterReadiness: Media status read triggered by ensureMediaStatus() call');
    
    try {
      // Use centralized command execution with assurance
      final command = CommandFactory.createGetMediaStatusCommand(_printer);
      final result = await _communicationPolicy.execute(
        () => command.execute(),
        command.operationName,
      );
      
      if (result.success && result.data != null) {
        _mediaStatus = result.data;
        _hasMedia = ParserUtil.hasMedia(result.data);
        _logger.info(
            'PrinterReadiness: Media status read: $_mediaStatus, hasMedia: $_hasMedia');
      } else {
        _mediaStatus = null;
        _hasMedia = null;
        _logger.warning(
            'PrinterReadiness: Failed to read media status: ${result.error?.message}');
      }
      _mediaRead = true;
    } catch (e) {
      _logger.error('PrinterReadiness: Error reading media status: $e');
      _mediaStatus = null;
      _hasMedia = null;
      _mediaRead = true;
    }
  }

  Future<void> _readHeadStatus() async {
    if (_headRead) {
      _logger.debug(
          'PrinterReadiness: Head status already read, skipping duplicate read');
      return;
    }

    _logger.info('PrinterReadiness: Reading head status');
    _logger.debug(
        'PrinterReadiness: Head status read triggered by ensureHeadStatus() call');
    
    try {
      // Use centralized command execution with assurance
      final command = CommandFactory.createGetHeadStatusCommand(_printer);
      final result = await _communicationPolicy.execute(
        () => command.execute(),
        command.operationName,
      );
      
      if (result.success && result.data != null) {
        _headStatus = result.data;
        _headClosed = ParserUtil.isHeadClosed(result.data);
        _logger.info(
            'PrinterReadiness: Head status read: $_headStatus, headClosed: $_headClosed');
      } else {
        _headStatus = null;
        _headClosed = null;
        _logger.warning(
            'PrinterReadiness: Failed to read head status: ${result.error?.message}');
      }
      _headRead = true;
    } catch (e) {
      _logger.error('PrinterReadiness: Error reading head status: $e');
      _headStatus = null;
      _headClosed = null;
      _headRead = true;
    }
  }

  Future<void> _readPauseStatus() async {
    if (_pauseRead) return;
    
    _logger.info('PrinterReadiness: Reading pause status');
    try {
      // Use centralized command execution with assurance
      final command = CommandFactory.createGetPauseStatusCommand(_printer);
      final result = await _communicationPolicy.execute(
        () => command.execute(),
        command.operationName,
      );
      
      if (result.success && result.data != null) {
        _pauseStatus = result.data;
        _isPaused = ParserUtil.toBool(result.data);
        _logger.info(
            'PrinterReadiness: Pause status read: $_pauseStatus, isPaused: $_isPaused');
      } else {
        _pauseStatus = null;
        _isPaused = null;
        _logger.warning(
            'PrinterReadiness: Failed to read pause status: ${result.error?.message}');
      }
      _pauseRead = true;
    } catch (e) {
      _logger.error('PrinterReadiness: Error reading pause status: $e');
      _pauseStatus = null;
      _isPaused = null;
      _pauseRead = true;
    }
  }
  
  Future<void> _readHostStatus() async {
    if (_hostRead) return;
    
    _logger.info('PrinterReadiness: Reading host status');
    try {
      // Use centralized command execution with assurance
      final command = CommandFactory.createGetHostStatusCommand(_printer);
      final result = await _communicationPolicy.execute(
        () => command.execute(),
        command.operationName,
      );
      
      if (result.success && result.data != null) {
        final hostStatusInfo = result.data!;
        _hostStatus = hostStatusInfo.details['rawStatus'] as String?;
        _logger.info('PrinterReadiness: Host status read: $hostStatusInfo');
        
        // Clear previous errors
        _errors.clear();
        
        // Only add errors if the status indicates problems
        if (!hostStatusInfo.isOk) {
          final errorMsg =
              hostStatusInfo.errorMessage ?? 'Printer error: $_hostStatus';
          _errors.add(errorMsg);
          _logger.warning(
              'PrinterReadiness: Host status indicates error: $errorMsg');
          
          // Add detailed error information
          if (hostStatusInfo.errorCode != null) {
            _errors.add('Error code: ${hostStatusInfo.errorCode}');
          }
          if (hostStatusInfo.details.isNotEmpty) {
            _errors.add('Details: ${hostStatusInfo.details}');
          }
        }
      } else {
        _hostStatus = null;
        _errors.clear();
        _logger.warning(
            'PrinterReadiness: Failed to read host status: ${result.error?.message}');
      }
      _hostRead = true;
    } catch (e) {
      _logger.error('PrinterReadiness: Error reading host status: $e');
      _hostStatus = null;
      _errors.clear();
      _hostRead = true;
    }
  }
  
  Future<void> _readLanguageStatus() async {
    if (_languageRead) {
      _logger.debug(
          'PrinterReadiness: Language status already read, skipping duplicate read');
      return;
    }
    
    _logger.info('PrinterReadiness: Reading language status');
    _logger.debug(
        'PrinterReadiness: Language status read triggered by ensureLanguageStatus() call');
    
    try {
      // Use centralized command execution with assurance
      final command = CommandFactory.createGetLanguageCommand(_printer);
      final result = await _communicationPolicy.execute(
        () => command.execute(),
        command.operationName,
      );
      
      if (result.success && result.data != null) {
        _languageStatus = result.data;
        _logger
            .info('PrinterReadiness: Language status read: $_languageStatus');
      } else {
        _languageStatus = null;
        _logger.warning(
            'PrinterReadiness: Failed to read language status: ${result.error?.message}');
      }
      _languageRead = true;
    } catch (e) {
      _logger.error('PrinterReadiness: Error reading language status: $e');
      _languageStatus = null;
      _languageRead = true;
    }
  }
  
  /// Get read status for diagnostics
  Map<String, bool> get readStatus {
    return {
      'connection': _connectionRead,
      'media': _mediaRead,
      'head': _headRead,
      'pause': _pauseRead,
      'host': _hostRead,
      'language': _languageRead,
    };
  }

  /// Get cached values for diagnostics (without triggering reads)
  Map<String, dynamic> get cachedValues {
    return {
      'connection': _connectionRead ? _isConnected : '<unchecked>',
      'mediaStatus': _mediaRead ? _mediaStatus : '<unchecked>',
      'hasMedia': _mediaRead ? _hasMedia : '<unchecked>',
      'headStatus': _headRead ? _headStatus : '<unchecked>',
      'headClosed': _headRead ? _headClosed : '<unchecked>',
      'pauseStatus': _pauseRead ? _pauseStatus : '<unchecked>',
      'isPaused': _pauseRead ? _isPaused : '<unchecked>',
      'hostStatus': _hostRead ? _hostStatus : '<unchecked>',
      'errors': _hostRead ? List.from(_errors) : '<unchecked>',
      'languageStatus': _languageRead ? _languageStatus : '<unchecked>',
    };
  }
  
  @override
  String toString() {
    return 'PrinterReadiness('
        'connection: ${_connectionRead ? _isConnected : '<unchecked>'}, '
        'media: ${_mediaRead ? _hasMedia : '<unchecked>'}, '
        'head: ${_headRead ? _headClosed : '<unchecked>'}, '
        'pause: ${_pauseRead ? _isPaused : '<unchecked>'}, '
        'host: ${_hostRead ? _hostStatus : '<unchecked>'}, '
        'language: ${_languageRead ? _languageStatus : '<unchecked>'}'
        ')';
  }

  /// Reset connection status and re-read
  Future<bool?> resetConnection() async {
    _connectionRead = false;
    _isConnected = null;
    return await isConnected;
  }

  /// Reset media status and re-read
  Future<String?> resetMediaStatus() async {
    _mediaRead = false;
    _mediaStatus = null;
    _hasMedia = null;
    return await mediaStatus;
  }

  /// Reset has media and re-read
  Future<bool?> resetHasMedia() async {
    _mediaRead = false;
    _mediaStatus = null;
    _hasMedia = null;
    return await hasMedia;
  }

  /// Reset head status and re-read
  Future<String?> resetHeadStatus() async {
    _headRead = false;
    _headStatus = null;
    _headClosed = null;
    return await headStatus;
  }

  /// Reset head closed and re-read
  Future<bool?> resetHeadClosed() async {
    _headRead = false;
    _headStatus = null;
    _headClosed = null;
    return await headClosed;
  }

  /// Reset pause status and re-read
  Future<String?> resetPauseStatus() async {
    _pauseRead = false;
    _pauseStatus = null;
    _isPaused = null;
    return await pauseStatus;
  }

  /// Reset is paused and re-read
  Future<bool?> resetIsPaused() async {
    _pauseRead = false;
    _pauseStatus = null;
    _isPaused = null;
    return await isPaused;
  }

  /// Reset host status and re-read
  Future<String?> resetHostStatus() async {
    _hostRead = false;
    _hostStatus = null;
    _errors.clear();
    return await hostStatus;
  }

  /// Reset errors and re-read
  Future<List<String>> resetErrors() async {
    _hostRead = false;
    _hostStatus = null;
    _errors.clear();
    return await errors;
  }

  /// Reset language status and re-read
  Future<String?> resetLanguageStatus() async {
    _languageRead = false;
    _languageStatus = null;
    return await languageStatus;
  }

  /// Reset all statuses and re-read
  Future<void> resetAllStatuses() async {
    _connectionRead = false;
    _mediaRead = false;
    _headRead = false;
    _pauseRead = false;
    _hostRead = false;
    _languageRead = false;

    _isConnected = null;
    _mediaStatus = null;
    _hasMedia = null;
    _headStatus = null;
    _headClosed = null;
    _pauseStatus = null;
    _isPaused = null;
    _hostStatus = null;
    _errors.clear();
    _languageStatus = null;

    await readAllStatuses();
  }
}

/// Represents printer readiness with correction tracking metadata
class CorrectedReadiness extends PrinterReadiness {

  CorrectedReadiness({
    required super.printer,
    required super.options,
    required this.appliedCorrections,
    required this.correctionResults,
    required this.correctionErrors,
    DateTime? correctionTimestamp,
  }) : correctionTimestamp = correctionTimestamp ?? DateTime.now();
  /// List of correction operations that were attempted
  final List<String> appliedCorrections;

  /// Results of correction attempts (operation -> success)
  final Map<String, bool> correctionResults;

  /// Timestamp when corrections were applied
  final DateTime correctionTimestamp;

  /// Error messages for failed corrections
  final Map<String, String> correctionErrors;

  /// Correction-specific computed properties
  bool get isPausedFixed => correctionResults['unpause'] ?? false;
  bool get isErrorsFixed => correctionResults['clearErrors'] ?? false;
  bool get isMediaFixed => correctionResults['calibrate'] ?? false;
  bool get isLanguageFixed => correctionResults['switchLanguage'] ?? false;
  bool get isBufferCleared => correctionResults['clearBuffer'] ?? false;

  /// Whether any corrections were attempted
  bool get hasCorrections => appliedCorrections.isNotEmpty;

  /// Whether all attempted corrections were successful
  bool get allCorrectionsSuccessful =>
      correctionResults.values.every((success) => success);

  /// Whether any corrections failed
  bool get hasFailedCorrections =>
      correctionResults.values.any((success) => !success);

  /// Summary of correction results
  String get correctionSummary {
    if (appliedCorrections.isEmpty) return 'No corrections applied';

    final successful = correctionResults.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    final failed = correctionResults.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();

    final parts = <String>[];
    if (successful.isNotEmpty) parts.add('Fixed: ${successful.join(', ')}');
    if (failed.isNotEmpty) parts.add('Failed: ${failed.join(', ')}');
    return parts.join('; ');
  }

  /// Detailed correction information for logging
  String get detailedCorrectionInfo {
    if (appliedCorrections.isEmpty) return 'No corrections attempted';

    final buffer = StringBuffer();
    buffer.writeln(
        'Corrections applied at ${correctionTimestamp.toIso8601String()}:');

    for (final correction in appliedCorrections) {
      final success = correctionResults[correction] ?? false;
      final error = correctionErrors[correction];

      buffer.write('  • $correction: ${success ? 'SUCCESS' : 'FAILED'}');
      if (error != null) buffer.write(' ($error)');
      buffer.writeln();
    }

    return buffer.toString();
  }

  @override
  Map<String, dynamic> get cachedValues {
    final baseMap = super.cachedValues;
    baseMap.addAll({
      'appliedCorrections': appliedCorrections,
      'correctionResults': correctionResults,
      'correctionErrors': correctionErrors,
      'correctionTimestamp': correctionTimestamp.toIso8601String(),
      'hasCorrections': hasCorrections,
      'allCorrectionsSuccessful': allCorrectionsSuccessful,
      'hasFailedCorrections': hasFailedCorrections,
      'correctionSummary': correctionSummary,
    });
    return baseMap;
  }
}
