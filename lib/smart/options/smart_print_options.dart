/// Smart print options with sensible defaults
class SmartPrintOptions {
  // Connection options
  final bool autoConnect;
  final bool autoDisconnect;
  final Duration connectionTimeout;
  final bool enableConnectionPooling;
  final int maxConnections;
  final Duration healthCheckInterval;
  final bool enableReconnection;

  // Caching options
  final bool enableCaching;
  final Duration cacheTtl;

  // Optimization options
  final bool enableOptimization;
  final bool enableMultichannel;
  final bool enableMFiOptimization;

  // iOS-specific options
  final bool enableIOSOptimization;
  final bool enableMulticast;

  // Retry options
  final int maxRetries;
  final Duration retryDelay;
  final double retryBackoff;

  // Format options
  final bool autoDetectFormat;
  final bool forceLanguageSwitch;

  // Buffer options
  final bool clearBufferBeforePrint;
  final bool flushBufferAfterPrint;

  /// Default constructor
  const SmartPrintOptions({
    this.autoConnect = true,
    this.autoDisconnect = false,
    this.connectionTimeout = const Duration(seconds: 10),
    this.enableConnectionPooling = true,
    this.maxConnections = 3,
    this.healthCheckInterval = const Duration(seconds: 60),
    this.enableReconnection = true,
    this.enableCaching = true,
    this.cacheTtl = const Duration(minutes: 30),
    this.enableOptimization = true,
    this.enableMultichannel = true,
    this.enableMFiOptimization = true,
    this.enableIOSOptimization = true,
    this.enableMulticast = true,
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 100),
    this.retryBackoff = 2.0,
    this.autoDetectFormat = true,
    this.forceLanguageSwitch = false,
    this.clearBufferBeforePrint = true,
    this.flushBufferAfterPrint = true,
  });

  /// Fast printing (minimal safety checks)
  const SmartPrintOptions.fast()
      : autoConnect = true,
        autoDisconnect = false,
        connectionTimeout = const Duration(seconds: 5),
        enableConnectionPooling = true,
        maxConnections = 5,
        healthCheckInterval = const Duration(seconds: 30),
        enableReconnection = true,
        enableCaching = true,
        cacheTtl = const Duration(minutes: 15),
        enableOptimization = true,
        enableMultichannel = true,
        enableMFiOptimization = true,
        enableIOSOptimization = true,
        enableMulticast = true,
        maxRetries = 2,
        retryDelay = const Duration(milliseconds: 50),
        retryBackoff = 1.5,
        autoDetectFormat = true,
        forceLanguageSwitch = false,
        clearBufferBeforePrint = false,
        flushBufferAfterPrint = false;

  /// Reliable printing (maximum safety)
  const SmartPrintOptions.reliable()
      : autoConnect = true,
        autoDisconnect = false,
        connectionTimeout = const Duration(seconds: 15),
        enableConnectionPooling = true,
        maxConnections = 2,
        healthCheckInterval = const Duration(seconds: 120),
        enableReconnection = true,
        enableCaching = true,
        cacheTtl = const Duration(minutes: 60),
        enableOptimization = true,
        enableMultichannel = true,
        enableMFiOptimization = true,
        enableIOSOptimization = true,
        enableMulticast = true,
        maxRetries = 5,
        retryDelay = const Duration(milliseconds: 200),
        retryBackoff = 2.0,
        autoDetectFormat = true,
        forceLanguageSwitch = false,
        clearBufferBeforePrint = true,
        flushBufferAfterPrint = true;

  /// Conservative printing (proven techniques only)
  const SmartPrintOptions.conservative()
      : autoConnect = true,
        autoDisconnect = true,
        connectionTimeout = const Duration(seconds: 20),
        enableConnectionPooling = false,
        maxConnections = 1,
        healthCheckInterval = const Duration(seconds: 300),
        enableReconnection = true,
        enableCaching = true,
        cacheTtl = const Duration(minutes: 120),
        enableOptimization = false,
        enableMultichannel = false,
        enableMFiOptimization = true,
        enableIOSOptimization = true,
        enableMulticast = false,
        maxRetries = 3,
        retryDelay = const Duration(milliseconds: 500),
        retryBackoff = 2.0,
        autoDetectFormat = true,
        forceLanguageSwitch = false,
        clearBufferBeforePrint = true,
        flushBufferAfterPrint = true;
} 