/// Status information for the Zebra Printer Smart API
class ZebraPrinterSmartStatus {
  final bool isConnected;
  final double cacheHitRate;
  final double connectionHealth;
  final Map<String, dynamic> performanceMetrics;
  final String? lastOperation;
  final double failureRate;
  final int averagePrintTime;

  const ZebraPrinterSmartStatus({
    required this.isConnected,
    required this.cacheHitRate,
    required this.connectionHealth,
    required this.performanceMetrics,
    this.lastOperation,
    required this.failureRate,
    required this.averagePrintTime,
  });
} 