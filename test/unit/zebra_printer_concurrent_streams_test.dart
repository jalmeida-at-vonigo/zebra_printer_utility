import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/native_models/method_channel_constants.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'package:zebrautil/zebra_printer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZebraPrinter concurrent discovery streams', () {
    late String instanceId;
    late MethodChannel mainChannel;
    ZebraPrinter? printer;

    setUp(() async {
      instanceId = 'inst_${DateTime.now().millisecondsSinceEpoch}';
      mainChannel = const MethodChannel(MethodChannelConstants.mainChannel);

      // Mock main channel getInstance
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mainChannel, (MethodCall call) async {
        if (call.method == MethodChannelConstants.getInstanceMethod) {
          return instanceId;
        }
        return null;
      });

      // Stub permission handler channel to avoid real permission checks
      // permission_handler uses 'plugins.flutter.io/permission_handler'
      const permissionChannel = MethodChannel('plugins.flutter.io/permission_handler');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, (MethodCall call) async {
        // Return granted-ish values; we won't parse in PermissionManager during tests
        return null;
      });

      printer = await ZebraPrinter.create();
    });

    tearDown(() {
      // Clear handlers
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mainChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/permission_handler'), null);
      printer?.dispose();
    });

    test('events are isolated per operation across concurrent streams', () async {
      final objectChannelName = 'ZebraPrinterObject$instanceId';
      final objectChannel = MethodChannel(objectChannelName);

      // Capture operationIds for each discovery method
      String? opLocal;
      String? opSubnet;
      int stopScanCalls = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(objectChannel, (MethodCall call) async {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        if (call.method == MethodChannelConstants.discoverLocalBroadcastMethod) {
          opLocal = args['operationId'] as String?;
        } else if (call.method == MethodChannelConstants.discoverSubnetMethod) {
          opSubnet = args['operationId'] as String?;
        } else if (call.method == MethodChannelConstants.stopScanMethod) {
          stopScanCalls += 1;
        }
        return null;
      });

      final localDevices = <ZebraDevice>[];
      final subnetDevices = <ZebraDevice>[];

      final localSub = printer!.discoverLocalBroadcastStream(timeout: 500)
          .listen(localDevices.add);
      final subnetSub = printer!
          .discoverSubnetStream(subnet: '192.168.1', timeout: 500)
          .listen(subnetDevices.add);

      // Wait for onOperationStart callbacks to fire and channels to be invoked
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(opLocal, isNotNull);
      expect(opSubnet, isNotNull);
      expect(opLocal, isNot(equals(opSubnet)));

      // Emit one device to each operation
      await printer!.nativeMethodCallHandler(MethodCall(
        MethodChannelConstants.discoverLocalBroadcastEventPrinterFound,
        {
          'operationId': opLocal,
          'Address': '192.168.1.49',
          'Name': 'LAN Local',
          'Status': 'Found',
          'IsWifi': true,
          'isBluetooth': false,
        },
      ));

      await printer!.nativeMethodCallHandler(MethodCall(
        MethodChannelConstants.discoverSubnetEventPrinterFound,
        {
          'operationId': opSubnet,
          'Address': '192.168.1.50',
          'Name': 'LAN Printer',
          'Status': 'Found',
          'IsWifi': true,
          'isBluetooth': false,
        },
      ));

      // Complete both operations
      await printer!.nativeMethodCallHandler(MethodCall(
        MethodChannelConstants.discoverLocalBroadcastCallbackOnComplete,
        {'operationId': opLocal, 'foundCount': 1},
      ));
      await printer!.nativeMethodCallHandler(MethodCall(
        MethodChannelConstants.discoverSubnetCallbackOnComplete,
        {'operationId': opSubnet, 'foundCount': 1},
      ));

      // Allow some time for events to propagate
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(localDevices.length, 1);
      expect(subnetDevices.length, 1);
      expect(localDevices.first.address, equals('192.168.1.49'));
      expect(subnetDevices.first.address, equals('192.168.1.50'));

      // Cancel subscriptions explicitly - individual cancellations should NOT trigger stopScan
      // This prevents premature stopping of concurrent discovery operations
      await localSub.cancel();
      await subnetSub.cancel();
      // Allow onCancel to process
      await Future<void>.delayed(const Duration(milliseconds: 20));
      
      // Individual stream cancellations should NOT trigger stopScan to prevent interference
      // with other concurrent discovery operations
      expect(stopScanCalls, equals(0));
    });
  });
}


