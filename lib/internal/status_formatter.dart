/// Utility class for formatting printer status data
/// Converts raw ZSDK status data to standardized dictionary format
class StatusFormatter {
  /// Format basic printer status from raw ZSDK data
  /// Takes raw status values and converts them to a standardized dictionary
  static Map<String, dynamic> formatBasicStatus({
    bool? isReadyToPrint,
    bool? isHeadOpen,
    bool? isPaperOut,
    bool? isPaused,
    bool? isRibbonOut,
    bool? isHeadCold,
    bool? isHeadTooHot,
    bool? isReceiveBufferFull,
    bool? isPartialFormatInProgress,
    int? labelLengthInDots,
    int? numberOfFormatsInReceiveBuffer,
    int? labelsRemainingInBatch,
    String? error,
  }) {
    return {
      'isReadyToPrint': isReadyToPrint ?? false,
      'isHeadOpen': isHeadOpen ?? false,
      'isPaperOut': isPaperOut ?? false,
      'isPaused': isPaused ?? false,
      'isRibbonOut': isRibbonOut ?? false,
      'isHeadCold': isHeadCold ?? false,
      'isHeadTooHot': isHeadTooHot ?? false,
      'isReceiveBufferFull': isReceiveBufferFull ?? false,
      'isPartialFormatInProgress': isPartialFormatInProgress ?? false,
      'labelLengthInDots': labelLengthInDots ?? 0,
      'numberOfFormatsInReceiveBuffer': numberOfFormatsInReceiveBuffer ?? 0,
      'labelsRemainingInBatch': labelsRemainingInBatch ?? 0,
      'error': error ?? '',
    };
  }

  /// Format detailed printer status from raw ZSDK data
  /// Combines basic status with additional SGD settings
  static Map<String, dynamic> formatDetailedStatus({
    required Map<String, dynamic> basicStatus,
    String? alerts,
    String? mediaType,
    String? printMode,
  }) {
    return {
      'basicStatus': basicStatus,
      'alerts': alerts ?? '',
      'mediaType': mediaType ?? '',
      'printMode': printMode ?? '',
    };
  }

  /// Create error status dictionary for connection failures
  static Map<String, dynamic> createErrorStatus(String errorMessage) {
    return formatBasicStatus(
      isReadyToPrint: false,
      isHeadOpen: false,
      isPaperOut: false,
      isPaused: false,
      isRibbonOut: false,
      error: errorMessage,
    );
  }

  /// Create detailed error status for connection failures
  static Map<String, dynamic> createDetailedErrorStatus(String errorMessage) {
    final basicStatus = createErrorStatus(errorMessage);
    return formatDetailedStatus(basicStatus: basicStatus);
  }
}