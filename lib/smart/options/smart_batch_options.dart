import 'smart_print_options.dart';

/// Batch print options
class SmartBatchOptions extends SmartPrintOptions {
  final int batchSize;
  final Duration batchDelay;
  final bool parallelProcessing;

  const SmartBatchOptions({
    super.autoConnect = true,
    super.autoDisconnect = false,
    super.connectionTimeout = const Duration(seconds: 10),
    super.enableConnectionPooling = true,
    super.maxConnections = 3,
    super.healthCheckInterval = const Duration(seconds: 60),
    super.enableReconnection = true,
    super.enableCaching = true,
    super.cacheTtl = const Duration(minutes: 30),
    super.enableOptimization = true,
    super.enableMultichannel = true,
    super.enableMFiOptimization = true,
    super.enableIOSOptimization = true,
    super.enableMulticast = true,
    super.maxRetries = 3,
    super.retryDelay = const Duration(milliseconds: 100),
    super.retryBackoff = 2.0,
    super.autoDetectFormat = true,
    super.forceLanguageSwitch = false,
    super.clearBufferBeforePrint = true,
    super.flushBufferAfterPrint = true,
    this.batchSize = 10,
    this.batchDelay = const Duration(milliseconds: 100),
    this.parallelProcessing = false,
  });

  const SmartBatchOptions.fast()
      : batchSize = 20,
        batchDelay = const Duration(milliseconds: 50),
        parallelProcessing = true,
        super.fast();

  const SmartBatchOptions.reliable()
      : batchSize = 5,
        batchDelay = const Duration(milliseconds: 200),
        parallelProcessing = false,
        super.reliable();
} 