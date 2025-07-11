import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'logger.dart';

/// Manages Bluetooth permissions for the Zebra printer plugin
class PermissionManager {
  static final Logger _logger = Logger.withPrefix('PermissionManager');
  
  /// Check if Bluetooth permissions are granted
  static Future<bool> checkBluetoothPermission() async {
    try {
      if (Platform.isIOS) {
        // On iOS, Bluetooth permissions work differently
        // The permission is granted when the user allows the app to use Bluetooth
        // We need to check if Bluetooth is available and enabled
        final status = await Permission.bluetooth.status;
        _logger.info('iOS Bluetooth permission status: $status');
        
        // On iOS, if status is not permanently denied, we can try to use Bluetooth
        // The actual permission request happens when we try to scan
        return status != PermissionStatus.permanentlyDenied;
      } else if (Platform.isAndroid) {
        // On Android, check multiple Bluetooth permissions
        final bluetoothStatus = await Permission.bluetooth.status;
        final bluetoothScanStatus = await Permission.bluetoothScan.status;
        final bluetoothConnectStatus = await Permission.bluetoothConnect.status;
        
        _logger.info('Android Bluetooth permissions - Bluetooth: $bluetoothStatus, Scan: $bluetoothScanStatus, Connect: $bluetoothConnectStatus');
        
        return bluetoothStatus.isGranted && 
               bluetoothScanStatus.isGranted && 
               bluetoothConnectStatus.isGranted;
      }
      return false;
    } catch (e) {
      _logger.error('Error checking Bluetooth permission', e);
      return false;
    }
  }
  
  /// Request Bluetooth permissions
  static Future<bool> requestBluetoothPermission() async {
    try {
      if (Platform.isIOS) {
        // On iOS, Bluetooth permissions are handled differently
        // The permission request happens when we actually try to use Bluetooth
        // For now, we'll just check the current status
        final status = await Permission.bluetooth.status;
        _logger.info('iOS Bluetooth permission status: $status');
        
        if (status == PermissionStatus.permanentlyDenied) {
          _logger.warning('iOS Bluetooth permission permanently denied');
          return false;
        }
        
        // On iOS, we can't explicitly request Bluetooth permission
        // The system will show the permission dialog when we try to scan
        _logger.info('iOS Bluetooth permission will be requested when scanning');
        return true;
      } else if (Platform.isAndroid) {
        // On Android, request all necessary Bluetooth permissions
        final bluetoothStatus = await Permission.bluetooth.request();
        final bluetoothScanStatus = await Permission.bluetoothScan.request();
        final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
        
        _logger.info('Android Bluetooth permission requests - Bluetooth: $bluetoothStatus, Scan: $bluetoothScanStatus, Connect: $bluetoothConnectStatus');
        
        return bluetoothStatus.isGranted && 
               bluetoothScanStatus.isGranted && 
               bluetoothConnectStatus.isGranted;
      }
      return false;
    } catch (e) {
      _logger.error('Error requesting Bluetooth permission', e);
      return false;
    }
  }
  
  /// Check if Bluetooth is enabled
  static Future<bool> isBluetoothEnabled() async {
    try {
      if (Platform.isIOS) {
        // On iOS, we can't directly check if Bluetooth is enabled
        // The native code will handle this
        return true;
      } else if (Platform.isAndroid) {
        // On Android, check if Bluetooth is enabled
        final bluetoothStatus = await Permission.bluetooth.status;
        return bluetoothStatus.isGranted;
      }
      return false;
    } catch (e) {
      _logger.error('Error checking if Bluetooth is enabled', e);
      return false;
    }
  }
  
  /// Get detailed permission status for debugging
  static Future<Map<String, dynamic>> getPermissionStatus() async {
    try {
      final Map<String, dynamic> status = {};
      
      if (Platform.isIOS) {
        status['bluetooth'] = (await Permission.bluetooth.status).toString();
      } else if (Platform.isAndroid) {
        status['bluetooth'] = (await Permission.bluetooth.status).toString();
        status['bluetoothScan'] = (await Permission.bluetoothScan.status).toString();
        status['bluetoothConnect'] = (await Permission.bluetoothConnect.status).toString();
        status['location'] = (await Permission.location.status).toString();
      }
      
      return status;
    } catch (e) {
      _logger.error('Error getting permission status', e);
      return {'error': e.toString()};
    }
  }
  
  /// Check if we should show permission rationale
  static Future<bool> shouldShowPermissionRationale() async {
    try {
      if (Platform.isIOS) {
        // iOS doesn't have a concept of "should show rationale"
        return false;
      } else if (Platform.isAndroid) {
        // On Android, check if we should show rationale for any Bluetooth permission
        // Note: shouldShowRequestRationale is not available in all versions
        // For now, return false to avoid API issues
        return false;
      }
      return false;
    } catch (e) {
      _logger.error('Error checking permission rationale', e);
      return false;
    }
  }
  
  /// Open app settings if permissions are permanently denied
  static Future<bool> openAppSettings() async {
    try {
      final opened = await openAppSettings();
      _logger.info('App settings opened: $opened');
      return opened;
    } catch (e) {
      _logger.error('Error opening app settings', e);
      return false;
    }
  }
} 