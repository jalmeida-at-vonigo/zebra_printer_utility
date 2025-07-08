import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/zebra_device.dart';
import 'logger.dart';

/// Manages persistent storage for printer preferences
class PrinterPreferences {
  static const String _keyLastSelectedPrinter = 'zebra_last_selected_printer';
  static const String _keyConnectionHistory = 'zebra_connection_history';
  static const String _keyPreferredConnectionType = 'zebra_preferred_connection_type';
  
  static final Logger _logger = Logger.withPrefix('PrinterPreferences');
  
  /// Save the last selected printer
  static Future<void> saveLastSelectedPrinter(ZebraDevice printer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final printerJson = printer.toJson();
      printerJson['lastUsed'] = DateTime.now().toIso8601String();
      await prefs.setString(_keyLastSelectedPrinter, jsonEncode(printerJson));
      _logger.info(
          'Saved last selected printer:  [1m${printer.name} (${printer.address})\u001b[0m');
    } catch (e) {
      _logger.error('Failed to save last selected printer', e);
    }
  }
  
  /// Get the last selected printer
  static Future<ZebraDevice?> getLastSelectedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyLastSelectedPrinter);
      if (jsonString == null) return null;
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      // Check if last used is recent (within 7 days)
      final lastUsed = DateTime.tryParse(json['lastUsed'] as String? ?? '') ??
          DateTime.now();
      final daysSinceLastUse = DateTime.now().difference(lastUsed).inDays;
      if (daysSinceLastUse > 7) {
        _logger.info('Last selected printer is too old ($daysSinceLastUse days), ignoring');
        return null;
      }
      return ZebraDevice.fromJson(json);
    } catch (e) {
      _logger.error('Failed to get last selected printer', e);
      return null;
    }
  }
  
  /// Save connection history for a printer
  static Future<void> saveConnectionHistory(String address, bool success) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_keyConnectionHistory);
      
      Map<String, dynamic> history = {};
      if (historyJson != null) {
        history = jsonDecode(historyJson) as Map<String, dynamic>;
      }
      
      // Get or create printer history
      final printerHistory = history[address] as Map<String, dynamic>? ?? {
        'successCount': 0,
        'failureCount': 0,
        'lastConnection': null,
      };
      
      // Update counts
      if (success) {
        printerHistory['successCount'] = (printerHistory['successCount'] as int) + 1;
      } else {
        printerHistory['failureCount'] = (printerHistory['failureCount'] as int) + 1;
      }
      printerHistory['lastConnection'] = DateTime.now().toIso8601String();
      
      // Save back
      history[address] = printerHistory;
      await prefs.setString(_keyConnectionHistory, jsonEncode(history));
      
      _logger.info('Updated connection history for $address: success=$success');
    } catch (e) {
      _logger.error('Failed to save connection history', e);
    }
  }
  
  /// Get connection success count for a printer
  static Future<int> getConnectionSuccessCount(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_keyConnectionHistory);
      
      if (historyJson == null) return 0;
      
      final history = jsonDecode(historyJson) as Map<String, dynamic>;
      final printerHistory = history[address] as Map<String, dynamic>?;
      
      if (printerHistory == null) return 0;
      
      return printerHistory['successCount'] as int? ?? 0;
    } catch (e) {
      _logger.error('Failed to get connection success count', e);
      return 0;
    }
  }
  
  /// Get all connection history
  static Future<Map<String, int>> getAllConnectionSuccessCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_keyConnectionHistory);
      
      if (historyJson == null) return {};
      
      final history = jsonDecode(historyJson) as Map<String, dynamic>;
      final successCounts = <String, int>{};
      
      history.forEach((address, data) {
        final printerHistory = data as Map<String, dynamic>;
        successCounts[address] = printerHistory['successCount'] as int? ?? 0;
      });
      
      return successCounts;
    } catch (e) {
      _logger.error('Failed to get all connection success counts', e);
      return {};
    }
  }
  
  /// Save preferred connection type
  static Future<void> savePreferredConnectionType(bool preferWiFi) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyPreferredConnectionType, preferWiFi);
      _logger.info('Saved preferred connection type: ${preferWiFi ? "WiFi" : "BLE"}');
    } catch (e) {
      _logger.error('Failed to save preferred connection type', e);
    }
  }
  
  /// Get preferred connection type
  static Future<bool> getPreferredConnectionType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyPreferredConnectionType) ?? true; // Default to WiFi
    } catch (e) {
      _logger.error('Failed to get preferred connection type', e);
      return true; // Default to WiFi
    }
  }
  
  /// Clear all preferences
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastSelectedPrinter);
      await prefs.remove(_keyConnectionHistory);
      await prefs.remove(_keyPreferredConnectionType);
      _logger.info('Cleared all printer preferences');
    } catch (e) {
      _logger.error('Failed to clear preferences', e);
    }
  }
} 