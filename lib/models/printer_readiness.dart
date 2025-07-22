import 'dart:async';

import '../internal/commands/command_factory.dart';
import '../internal/logger.dart';
import '../internal/parser_util.dart';
import '../internal/policies/policies.dart' as policies;
import '../zebra_printer.dart';
import 'readiness_options.dart';

/// Lazy printer readiness status that only calls commands when first accessed
class PrinterReadiness {

  /// Constructor
  PrinterReadiness({
    required ZebraPrinter printer,
    ReadinessOptions? options,
  })  : _printer = printer,
        _options = options;
        
  final ZebraPrinter _printer;
  final Logger _logger = Logger.withPrefix('PrinterReadiness');

  // Readiness options to control what gets read
  final ReadinessOptions? _options;

  // Completers for lazy loading - prevents concurrent reads
  Completer<bool?>? _connectionCompleter;
  Completer<String?>? _mediaStatusCompleter;
  Completer<bool?>? _hasMediaCompleter;
  Completer<String?>? _headStatusCompleter;
  Completer<bool?>? _headClosedCompleter;
  Completer<String?>? _pauseStatusCompleter;
  Completer<bool?>? _isPausedCompleter;
  Completer<String?>? _hostStatusCompleter;
  Completer<List<String>>? _errorsCompleter;
  Completer<String?>? _languageStatusCompleter;

  // Error tracking for status reads
  String? _lastConnectionError;
  String? _lastMediaError;
  String? _lastHeadError;
  String? _lastPauseError;
  String? _lastHostError;
  String? _lastLanguageError;

  // Private fields to store actual values
  String? _mediaStatus;
  bool? _hasMedia;
  String? _headStatus;
  bool? _headClosed;
  String? _pauseStatus;
  bool? _isPaused;
  String? _hostStatus;
  List<String> _errors = [];
  String? _languageStatus;

  // Timeout policy for all operations
  static final _timeoutPolicy =
      policies.TimeoutPolicy.of(const Duration(seconds: 7));

  /// Get connection status (lazy)
  Future<bool?> get isConnected async {
    if (_connectionCompleter == null && (_options?.checkConnection ?? true)) {
      _connectionCompleter = Completer<bool?>();
      _readConnectionStatus()
          .then((connected) => _connectionCompleter!.complete(connected))
          .catchError((error) {
        _lastConnectionError = error.toString();
        _connectionCompleter!.complete(null);
      });
    }
    return _connectionCompleter?.future ?? Future.value(null);
  }

  /// Whether connection status has been read
  bool get wasConnectionRead => _connectionCompleter?.isCompleted ?? false;

  /// Get media status (lazy)
  Future<String?> get mediaStatus async {
    if (_mediaStatusCompleter == null && (_options?.checkMedia ?? true)) {
      _mediaStatusCompleter = Completer<String?>();
      _readMediaStatus()
          .then((_) => _mediaStatusCompleter!.complete(_mediaStatus))
          .catchError((error) {
        _lastMediaError = error.toString();
        _mediaStatusCompleter!.complete(null);
      });
    }
    return _mediaStatusCompleter?.future ?? Future.value(null);
  }

  /// Whether media status has been read
  bool get wasMediaRead => _mediaStatusCompleter?.isCompleted ?? false;

  /// Get has media (lazy)
  Future<bool?> get hasMedia async {
    if (_hasMediaCompleter == null && (_options?.checkMedia ?? true)) {
      _hasMediaCompleter = Completer<bool?>();
      // Ensure media status is read first
      final status = await mediaStatus;
      _hasMediaCompleter!
          .complete(status != null ? ParserUtil.hasMedia(status) : null);
    }
    return _hasMediaCompleter?.future ?? Future.value(null);
  }

  /// Whether has media has been read
  bool get wasHasMediaRead => _hasMediaCompleter?.isCompleted ?? false;

  /// Get head status (lazy)
  Future<String?> get headStatus async {
    if (_headStatusCompleter == null && (_options?.checkHead ?? true)) {
      _headStatusCompleter = Completer<String?>();
      _readHeadStatus()
          .then((_) => _headStatusCompleter!.complete(_headStatus))
          .catchError((error) {
        _lastHeadError = error.toString();
        _headStatusCompleter!.complete(null);
      });
    }
    return _headStatusCompleter?.future ?? Future.value(null);
  }

  /// Whether head status has been read
  bool get wasHeadRead => _headStatusCompleter?.isCompleted ?? false;

  /// Get head closed status (lazy)
  Future<bool?> get headClosed async {
    if (_headClosedCompleter == null && (_options?.checkHead ?? true)) {
      _headClosedCompleter = Completer<bool?>();
      // Ensure head status is read first
      final status = await headStatus;
      _headClosedCompleter!
          .complete(status != null ? ParserUtil.isHeadClosed(status) : null);
    }
    return _headClosedCompleter?.future ?? Future.value(null);
  }

  /// Whether head closed has been read
  bool get wasHeadClosedRead => _headClosedCompleter?.isCompleted ?? false;

  /// Get pause status (lazy)
  Future<String?> get pauseStatus async {
    if (_pauseStatusCompleter == null && (_options?.checkPause ?? true)) {
      _pauseStatusCompleter = Completer<String?>();
      _readPauseStatus()
          .then((_) => _pauseStatusCompleter!.complete(_pauseStatus))
          .catchError((error) {
        _lastPauseError = error.toString();
        _pauseStatusCompleter!.complete(null);
      });
    }
    return _pauseStatusCompleter?.future ?? Future.value(null);
  }

  /// Whether pause status has been read
  bool get wasPauseRead => _pauseStatusCompleter?.isCompleted ?? false;

  /// Get is paused status (lazy)
  Future<bool?> get isPaused async {
    if (_isPausedCompleter == null && (_options?.checkPause ?? true)) {
      _isPausedCompleter = Completer<bool?>();
      // Ensure pause status is read first
      final status = await pauseStatus;
      _isPausedCompleter!
          .complete(status != null ? ParserUtil.toBool(status) : null);
    }
    return _isPausedCompleter?.future ?? Future.value(null);
  }

  /// Whether is paused has been read
  bool get wasIsPausedRead => _isPausedCompleter?.isCompleted ?? false;

  /// Get host status (lazy)
  Future<String?> get hostStatus async {
    if (_hostStatusCompleter == null && (_options?.checkErrors ?? true)) {
      _hostStatusCompleter = Completer<String?>();
      _readHostStatus()
          .then((_) => _hostStatusCompleter!.complete(_hostStatus))
          .catchError((error) {
        _lastHostError = error.toString();
        _hostStatusCompleter!.complete(null);
      });
    }
    return _hostStatusCompleter?.future ?? Future.value(null);
  }

  /// Whether host status has been read
  bool get wasHostRead => _hostStatusCompleter?.isCompleted ?? false;

  /// Get errors (lazy)
  Future<List<String>> get errors async {
    if (_errorsCompleter == null && (_options?.checkErrors ?? true)) {
      _errorsCompleter = Completer<List<String>>();
      // Ensure host status is read first
      await hostStatus;
      _errorsCompleter!.complete(List.unmodifiable(_errors));
    }
    return _errorsCompleter?.future ?? Future.value([]);
  }

  /// Whether errors have been read
  bool get wasErrorsRead => _errorsCompleter?.isCompleted ?? false;

  /// Get language status (lazy)
  Future<String?> get languageStatus async {
    if (_languageStatusCompleter == null && (_options?.checkLanguage ?? true)) {
      _languageStatusCompleter = Completer<String?>();
      _readLanguageStatus()
          .then((_) => _languageStatusCompleter!.complete(_languageStatus))
          .catchError((error) {
        _lastLanguageError = error.toString();
        _languageStatusCompleter!.complete(null);
      });
    }
    return _languageStatusCompleter?.future ?? Future.value(null);
  }

  /// Whether language status has been read
  bool get wasLanguageRead => _languageStatusCompleter?.isCompleted ?? false;

  /// Get overall readiness status (lazy)
  /// Does NOT trigger new reads if values are already cached
  bool get isReady {
    // Check if all configured checks have been done and passed
    // Note: This uses cached values and doesn't trigger new reads

    // Use cached values to avoid triggering new reads
    final connectionReady =
        wasConnectionRead || !(_options?.checkConnection ?? true);
    final mediaReady = wasHasMediaRead || !(_options?.checkMedia ?? true);
    final headReady = wasHeadClosedRead || !(_options?.checkHead ?? true);
    final pauseReady = wasIsPausedRead || !(_options?.checkPause ?? true);
    final errorsReady = wasErrorsRead || !(_options?.checkErrors ?? true);

    return connectionReady &&
        mediaReady &&
        headReady &&
        pauseReady &&
        errorsReady;
  }

  /// Force read all statuses based on options
  Future<void> readAllStatuses() async {
    _logger.info('PrinterReadiness: Reading all statuses based on options');

    await isConnected;
    await mediaStatus;
    await headStatus;
    await pauseStatus;
    await hostStatus;
    await languageStatus;
  }

  /// Set cached values (for use during prepare process)
  void setCachedConnection(bool connected) {
    _connectionCompleter ??= Completer<bool?>();
    _connectionCompleter!.complete(connected);
    _lastConnectionError = null;
  }

  void setCachedMedia(String status, bool hasMedia) {
    _mediaStatusCompleter ??= Completer<String?>();
    _mediaStatusCompleter!.complete(status);
    _mediaStatus = status;
    _hasMedia = hasMedia;

    _hasMediaCompleter ??= Completer<bool?>();
    _hasMediaCompleter!.complete(hasMedia);
    
    _lastMediaError = null;
  }

  void setCachedHead(String status, bool headClosed) {
    _headStatusCompleter ??= Completer<String?>();
    _headStatusCompleter!.complete(status);
    _headStatus = status;
    _headClosed = headClosed;

    _headClosedCompleter ??= Completer<bool?>();
    _headClosedCompleter!.complete(headClosed);
    
    _lastHeadError = null;
  }

  void setCachedPause(String status, bool isPaused) {
    _pauseStatusCompleter ??= Completer<String?>();
    _pauseStatusCompleter!.complete(status);
    _pauseStatus = status;
    _isPaused = isPaused;

    _isPausedCompleter ??= Completer<bool?>();
    _isPausedCompleter!.complete(isPaused);
    
    _lastPauseError = null;
  }

  void setCachedHost(String status, List<String> errors) {
    _hostStatusCompleter ??= Completer<String?>();
    _hostStatusCompleter!.complete(status);
    _hostStatus = status;
    _errors = List.from(errors);

    _errorsCompleter ??= Completer<List<String>>();
    _errorsCompleter!.complete(List.from(errors));
    
    _lastHostError = null;
  }

  void setCachedLanguage(String status) {
    _languageStatusCompleter ??= Completer<String?>();
    _languageStatusCompleter!.complete(status);
    _languageStatus = status;
    _lastLanguageError = null;
  }

  // Private methods to read statuses
  Future<bool> _readConnectionStatus() async {
    _logger.info('PrinterReadiness: Reading connection status');
    
    try {
      // Use timeout policy directly for connection check
      final result =
          await _timeoutPolicy.execute(() => _printer.isPrinterConnected());
      final connected = result.success && (result.data ?? false);
      _lastConnectionError = null;
      _logger.info('PrinterReadiness: Connection status read: $connected');
      return connected;
    } catch (e) {
      _lastConnectionError = e.toString();
      _logger.error('PrinterReadiness: Error reading connection status: $e');
      return false;
    }
  }

  Future<void> _readMediaStatus() async {
    if (_mediaStatusCompleter == null) return;

    _logger.info('PrinterReadiness: Reading media status');
    _logger.debug(
        'PrinterReadiness: Media status read triggered by ensureMediaStatus() call');
    
    try {
      // Use centralized command execution with assurance
      final command = CommandFactory.createGetMediaStatusCommand(_printer);
      final result = await _timeoutPolicy.execute(() => command.execute());
      
      if (result.success && result.data != null) {
        _mediaStatus = result.data;
        _lastMediaError = null;
        _logger.info(
            'PrinterReadiness: Media status read: ${result.data}, hasMedia: ${ParserUtil.hasMedia(result.data)}');
      } else {
        _mediaStatus = null;
        _lastMediaError = result.error?.message ?? 'Unknown media status error';
        _logger.warning(
            'PrinterReadiness: Failed to read media status: ${result.error?.message}');
      }
    } catch (e) {
      _lastMediaError = e.toString();
      _mediaStatus = null;
      _logger.error('PrinterReadiness: Error reading media status: $e');
    }
  }

  Future<void> _readHeadStatus() async {
    if (_headStatusCompleter == null) return;

    _logger.info('PrinterReadiness: Reading head status');
    _logger.debug(
        'PrinterReadiness: Head status read triggered by ensureHeadStatus() call');
    
    try {
      // Use centralized command execution with assurance
      final command = CommandFactory.createGetHeadStatusCommand(_printer);
      final result = await _timeoutPolicy.execute(() => command.execute());
      
      if (result.success && result.data != null) {
        _headStatus = result.data;
        _lastHeadError = null;
        _logger.info(
            'PrinterReadiness: Head status read: ${result.data}, headClosed: ${ParserUtil.isHeadClosed(result.data)}');
      } else {
        _headStatus = null;
        _lastHeadError = result.error?.message ?? 'Unknown head status error';
        _logger.warning(
            'PrinterReadiness: Failed to read head status: ${result.error?.message}');
      }
    } catch (e) {
      _lastHeadError = e.toString();
      _headStatus = null;
      _logger.error('PrinterReadiness: Error reading head status: $e');
    }
  }

  Future<void> _readPauseStatus() async {
    if (_pauseStatusCompleter == null) return;
    
    _logger.info('PrinterReadiness: Reading pause status');
    try {
      // Use centralized command execution with assurance
      final command = CommandFactory.createGetPauseStatusCommand(_printer);
      final result = await _timeoutPolicy.execute(() => command.execute());
      
      if (result.success && result.data != null) {
        _pauseStatus = result.data;
        _lastPauseError = null;
        _logger.info(
            'PrinterReadiness: Pause status read: ${result.data}, isPaused: ${ParserUtil.toBool(result.data)}');
      } else {
        _pauseStatus = null;
        _lastPauseError = result.error?.message ?? 'Unknown pause status error';
        _logger.warning(
            'PrinterReadiness: Failed to read pause status: ${result.error?.message}');
      }
    } catch (e) {
      _lastPauseError = e.toString();
      _pauseStatus = null;
      _logger.error('PrinterReadiness: Error reading pause status: $e');
    }
  }
  
  Future<void> _readHostStatus() async {
    if (_hostStatusCompleter == null) return;
    
    _logger.info('PrinterReadiness: Reading host status');
    try {
      // Use centralized command execution with assurance
      final command = CommandFactory.createGetHostStatusCommand(_printer);
      final result = await _timeoutPolicy.execute(() => command.execute());
      
      if (result.success && result.data != null) {
        final hostStatusInfo = result.data!;
        _hostStatus = hostStatusInfo.details['rawStatus'] as String?;
        _lastHostError = null;
        _logger.info('PrinterReadiness: Host status read: $hostStatusInfo');
        
        // Clear previous errors
        _errors = [];
        
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
        _lastHostError = result.error?.message ?? 'Unknown host status error';
        _errors = [];
        _logger.warning(
            'PrinterReadiness: Failed to read host status: ${result.error?.message}');
      }
    } catch (e) {
      _lastHostError = e.toString();
      _hostStatus = null;
      _errors = [];
      _logger.error('PrinterReadiness: Error reading host status: $e');
    }
  }
  
  Future<void> _readLanguageStatus() async {
    if (_languageStatusCompleter == null) return;
    
    _logger.info('PrinterReadiness: Reading language status');
    _logger.debug(
        'PrinterReadiness: Language status read triggered by ensureLanguageStatus() call');
    
    try {
      // Use centralized command execution with assurance
      final command = CommandFactory.createGetLanguageCommand(_printer);
      final result = await _timeoutPolicy.execute(() => command.execute());
      
      if (result.success && result.data != null) {
        _languageStatus = result.data;
        _lastLanguageError = null;
        _logger
            .info('PrinterReadiness: Language status read: ${result.data}');
      } else {
        _languageStatus = null;
        _lastLanguageError =
            result.error?.message ?? 'Unknown language status error';
        _logger.warning(
            'PrinterReadiness: Failed to read language status: ${result.error?.message}');
      }
    } catch (e) {
      _lastLanguageError = e.toString();
      _languageStatus = null;
      _logger.error('PrinterReadiness: Error reading language status: $e');
    }
  }
  
  /// Get read status for each check
  Map<String, bool> get readStatus {
    return {
      'connection': wasConnectionRead,
      'media': wasMediaRead,
      'hasMedia': wasHasMediaRead,
      'head': wasHeadRead,
      'headClosed': wasHeadClosedRead,
      'pause': wasPauseRead,
      'isPaused': wasIsPausedRead,
      'host': wasHostRead,
      'errors': wasErrorsRead,
      'language': wasLanguageRead,
    };
  }

  /// Get cached values
  Map<String, dynamic> get cachedValues {
    return {
      'connection': wasConnectionRead ? 'checked' : '<unchecked>',
      'mediaStatus': wasMediaRead ? (_mediaStatus ?? '<null>') : '<unchecked>',
      'hasMedia': wasHasMediaRead ? _hasMedia : '<unchecked>',
      'headStatus': wasHeadRead ? (_headStatus ?? '<null>') : '<unchecked>',
      'headClosed': wasHeadClosedRead ? _headClosed : '<unchecked>',
      'pauseStatus': wasPauseRead ? (_pauseStatus ?? '<null>') : '<unchecked>',
      'isPaused': wasIsPausedRead ? _isPaused : '<unchecked>',
      'hostStatus': wasHostRead ? (_hostStatus ?? '<null>') : '<unchecked>',
      'errors': wasErrorsRead ? List.from(_errors) : '<unchecked>',
      'languageStatus':
          wasLanguageRead ? (_languageStatus ?? '<null>') : '<unchecked>',
    };
  }
  
  @override
  String toString() {
    return 'PrinterReadiness('
        'connection: ${wasConnectionRead ? 'checked' : '<unchecked>'}, '
        'media: ${wasMediaRead ? 'checked' : '<unchecked>'}, '
        'head: ${wasHeadRead ? 'checked' : '<unchecked>'}, '
        'pause: ${wasPauseRead ? 'checked' : '<unchecked>'}, '
        'host: ${wasHostRead ? 'checked' : '<unchecked>'}, '
        'language: ${wasLanguageRead ? 'checked' : '<unchecked>'}'
        ')';
  }

  /// Reset connection status and re-read
  Future<bool?> resetConnection() async {
    _connectionCompleter = null;
    _lastConnectionError = null;
    return await isConnected;
  }

  /// Reset media status and re-read
  Future<String?> resetMediaStatus() async {
    _mediaStatusCompleter = null;
    _lastMediaError = null;
    return await mediaStatus;
  }

  /// Reset has media and re-read
  Future<bool?> resetHasMedia() async {
    _hasMediaCompleter = null;
    _lastMediaError = null;
    return await hasMedia;
  }

  /// Reset head status and re-read
  Future<String?> resetHeadStatus() async {
    _headStatusCompleter = null;
    _lastHeadError = null;
    return await headStatus;
  }

  /// Reset head closed and re-read
  Future<bool?> resetHeadClosed() async {
    _headClosedCompleter = null;
    _lastHeadError = null;
    return await headClosed;
  }

  /// Reset pause status and re-read
  Future<String?> resetPauseStatus() async {
    _pauseStatusCompleter = null;
    _lastPauseError = null;
    return await pauseStatus;
  }

  /// Reset is paused and re-read
  Future<bool?> resetIsPaused() async {
    _isPausedCompleter = null;
    _lastPauseError = null;
    return await isPaused;
  }

  /// Reset host status and re-read
  Future<String?> resetHostStatus() async {
    _hostStatusCompleter = null;
    _lastHostError = null;
    _errors = [];
    return await hostStatus;
  }

  /// Reset errors and re-read
  Future<List<String>> resetErrors() async {
    _errorsCompleter?.complete([]);
    _lastHostError = null;
    return await errors;
  }

  /// Reset language status and re-read
  Future<String?> resetLanguageStatus() async {
    _languageStatusCompleter = null;
    _lastLanguageError = null;
    return await languageStatus;
  }

  /// Reset all statuses and re-read
  Future<void> resetAllStatuses() async {
    _connectionCompleter = null;
    _mediaStatusCompleter = null;
    _hasMediaCompleter = null;
    _headStatusCompleter = null;
    _headClosedCompleter = null;
    _pauseStatusCompleter = null;
    _isPausedCompleter = null;
    _hostStatusCompleter = null;
    _languageStatusCompleter = null;
    _errorsCompleter?.complete([]);

    _lastConnectionError = null;
    _lastMediaError = null;
    _lastHeadError = null;
    _lastPauseError = null;
    _lastHostError = null;
    _lastLanguageError = null;

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
