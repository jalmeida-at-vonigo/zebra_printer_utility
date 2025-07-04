/// Discovery options
class DiscoveryOptions {
  final Duration timeout;
  final bool includeBluetooth;
  final bool includeNetwork;
  final bool includeUSB;
  final int maxDevices;
  final bool enableMFiDiscovery;

  const DiscoveryOptions({
    this.timeout = const Duration(seconds: 10),
    this.includeBluetooth = true,
    this.includeNetwork = true,
    this.includeUSB = true,
    this.maxDevices = 10,
    this.enableMFiDiscovery = true,
  });
} 