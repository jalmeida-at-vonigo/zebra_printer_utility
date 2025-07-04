/// Connection options
class ConnectOptions {
  final bool enablePooling;
  final int maxConnections;
  final Duration healthCheckInterval;
  final bool enableReconnection;
  final bool enableMFiOptimization;
  final bool enableMulticast;

  const ConnectOptions({
    this.enablePooling = true,
    this.maxConnections = 3,
    this.healthCheckInterval = const Duration(seconds: 60),
    this.enableReconnection = true,
    this.enableMFiOptimization = true,
    this.enableMulticast = true,
  });
} 