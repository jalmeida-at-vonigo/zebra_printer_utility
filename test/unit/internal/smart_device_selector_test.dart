import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/smart_device_selector.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'package:zebrautil/models/smart_discovery_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('SmartDeviceSelector', () {
    group('selectOptimalPrinter', () {
      test('returns null for empty list', () async {
        final result = await SmartDeviceSelector.selectOptimalPrinter([]);
        expect(result, isNull);
      });

      test('returns single printer when only one available', () async {
        final printer = ZebraDevice(
          address: '192.168.1.100',
          name: 'ZQ520',
          status: 'Found',
          isWifi: true,
        );
        
        final result = await SmartDeviceSelector.selectOptimalPrinter([printer]);
        expect(result, equals(printer));
      });

      test('prefers previously selected printer if still available', () async {
        final printer1 = ZebraDevice(
          address: '192.168.1.100',
          name: 'ZQ520',
          status: 'Found',
          isWifi: true,
        );
        
        final printer2 = ZebraDevice(
          address: '192.168.1.101',
          name: 'RW420',
          status: 'Found',
          isWifi: true,
        );
        
        final result = await SmartDeviceSelector.selectOptimalPrinter(
          [printer1, printer2],
          previouslySelected: printer1,
        );
        
        expect(result, equals(printer1));
      });

      test('prefers WiFi over BLE when preferWiFi is true', () async {
        final wifiPrinter = ZebraDevice(
          address: '192.168.1.100',
          name: 'Generic Printer',
          status: 'Found',
          isWifi: true,
        );
        
        final blePrinter = ZebraDevice(
          address: 'AA:BB:CC:DD:EE:FF',
          name: 'Generic Printer',
          status: 'Found',
          isWifi: false,
        );
        
        final result = await SmartDeviceSelector.selectOptimalPrinter(
          [blePrinter, wifiPrinter],
          preferWiFi: true,
        );
        
        expect(result, equals(wifiPrinter));
      });

      test('prefers BLE over WiFi when preferWiFi is false', () async {
        final wifiPrinter = ZebraDevice(
          address: '192.168.1.100',
          name: 'Generic Printer',
          status: 'Found',
          isWifi: true,
        );
        
        final blePrinter = ZebraDevice(
          address: 'AA:BB:CC:DD:EE:FF',
          name: 'Generic Printer',
          status: 'Found',
          isWifi: false,
        );
        
        final result = await SmartDeviceSelector.selectOptimalPrinter(
          [wifiPrinter, blePrinter],
          preferWiFi: false,
        );
        
        expect(result, equals(blePrinter));
      });

      test('prefers higher model priority', () async {
        final rw420 = ZebraDevice(
          address: '192.168.1.100',
          name: 'RW420',
          status: 'Found',
          isWifi: true,
        );
        
        final zq510 = ZebraDevice(
          address: '192.168.1.101',
          name: 'ZQ510',
          status: 'Found',
          isWifi: true,
        );
        
        final genericPrinter = ZebraDevice(
          address: '192.168.1.102',
          name: 'Generic Printer',
          status: 'Found',
          isWifi: true,
        );
        
        final result = await SmartDeviceSelector.selectOptimalPrinter(
          [genericPrinter, zq510, rw420],
        );
        
        // RW420 has highest priority
        expect(result, equals(rw420));
      });

      test('considers connection status in scoring', () async {
        final connectedPrinter = ZebraDevice(
          address: '192.168.1.100',
          name: 'Generic Printer',
          status: 'Connected',
          isWifi: true,
        );
        
        final foundPrinter = ZebraDevice(
          address: '192.168.1.101',
          name: 'Generic Printer',
          status: 'Found',
          isWifi: true,
        );
        
        final result = await SmartDeviceSelector.selectOptimalPrinter(
          [foundPrinter, connectedPrinter],
        );
        
        // Connected printer should be preferred
        expect(result, equals(connectedPrinter));
      });
    });

    group('recordSuccessfulConnection', () {
      test('records successful connections', () async {
        const address = '192.168.1.100';
        
        // Record multiple successful connections
        await SmartDeviceSelector.recordSuccessfulConnection(address);
        await SmartDeviceSelector.recordSuccessfulConnection(address);
        await SmartDeviceSelector.recordSuccessfulConnection(address);
        
        // Create printers
        final successfulPrinter = ZebraDevice(
          address: address,
          name: 'Generic Printer',
          status: 'Found',
          isWifi: true,
        );
        
        final newPrinter = ZebraDevice(
          address: '192.168.1.101',
          name: 'Generic Printer',
          status: 'Found',
          isWifi: true,
        );
        
        // The printer with successful connections should be preferred
        final result = await SmartDeviceSelector.selectOptimalPrinter(
          [newPrinter, successfulPrinter],
        );
        
        expect(result, equals(successfulPrinter));
      });
    });

    group('SmartDiscoveryResult', () {
      test('sortedPrinters returns all printers when no selection', () {
        final printers = [
          ZebraDevice(
            address: '192.168.1.100',
            name: 'Printer 1',
            status: 'Found',
            isWifi: true,
          ),
          ZebraDevice(
            address: '192.168.1.101',
            name: 'Printer 2',
            status: 'Found',
            isWifi: true,
          ),
        ];
        
        final result = SmartDiscoveryResult(
          selectedPrinter: null,
          allPrinters: printers,
          isComplete: true,
          discoveryDuration: const Duration(seconds: 5),
        );
        
        expect(result.sortedPrinters, equals(printers));
      });

      test('sortedPrinters puts selected printer first', () {
        final printer1 = ZebraDevice(
          address: '192.168.1.100',
          name: 'Printer 1',
          status: 'Found',
          isWifi: true,
        );
        
        final printer2 = ZebraDevice(
          address: '192.168.1.101',
          name: 'Printer 2',
          status: 'Found',
          isWifi: true,
        );
        
        final result = SmartDiscoveryResult(
          selectedPrinter: printer2,
          allPrinters: [printer1, printer2],
          isComplete: true,
          discoveryDuration: const Duration(seconds: 5),
        );
        
        expect(result.sortedPrinters.first, equals(printer2));
        expect(result.sortedPrinters.last, equals(printer1));
      });
    });
  });
} 