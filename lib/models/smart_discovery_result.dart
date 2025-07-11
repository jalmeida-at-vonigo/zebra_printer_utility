import 'zebra_device.dart';

/// Helper class to store device with score
class ScoredDevice {
  ScoredDevice(this.device, this.score);
  
  final ZebraDevice device;
  final double score;
}

/// Result of smart discovery operation
class SmartDiscoveryResult {
  SmartDiscoveryResult({
    required this.selectedPrinter,
    required this.allPrinters,
    required this.isComplete,
    required this.discoveryDuration,
  });

  final ZebraDevice? selectedPrinter;
  final List<ZebraDevice> allPrinters;
  final bool isComplete;
  final Duration discoveryDuration;
  
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