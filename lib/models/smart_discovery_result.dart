import 'zebra_device.dart';

/// Helper class to store device with score
class ScoredDevice {
  final ZebraDevice device;
  final double score;
  
  ScoredDevice(this.device, this.score);
}

/// Result of smart discovery
class SmartDiscoveryResult {
  final ZebraDevice? selectedPrinter;
  final List<ZebraDevice> allPrinters;
  final bool isComplete;
  final Duration discoveryDuration;
  
  SmartDiscoveryResult({
    required this.selectedPrinter,
    required this.allPrinters,
    required this.isComplete,
    required this.discoveryDuration,
  });
  
  /// Get printers sorted by smart selection score
  List<ZebraDevice> get sortedPrinters {
    if (selectedPrinter == null) return allPrinters;
    
    // Put selected printer first, then sort others
    final others = allPrinters.where((p) => p.address != selectedPrinter!.address).toList();
    
    return [
      selectedPrinter!,
      ...others,
    ];
  }
} 