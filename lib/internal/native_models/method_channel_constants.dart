/// Constants for all method channel communication between native and Dart
/// This must be kept in sync with iOS MethodChannelConstants.swift
class MethodChannelConstants {
  // Private constructor to prevent instantiation
  MethodChannelConstants._();

  // Channel Names
  static const String mainChannel = 'zebrautil';

  // getInstance
  static const String getInstanceMethod = 'getInstance';

  // connectToPrinter
  static const String connectToPrinterMethod = 'connectToPrinter';
  static const String connectToPrinterCallbackOnComplete = 'connectToPrinter_onComplete';
  static const String connectToPrinterCallbackOnError = 'connectToPrinter_onError';

  // disconnect
  static const String disconnectMethod = 'disconnect';
  static const String disconnectCallbackOnComplete = 'disconnect_onComplete';
  static const String disconnectCallbackOnError = 'disconnect_onError';

  // isConnected
  static const String isConnectedMethod = 'isConnected';
  static const String isConnectedCallbackOnResult = 'isConnected_onResult';

  // print
  static const String printMethod = 'print';
  static const String printCallbackOnComplete = 'print_onComplete';
  static const String printCallbackOnError = 'print_onError';
  static const String printEventStatusUpdate = 'print_statusUpdate';
  static const String printEventProgressUpdate = 'print_progressUpdate';

  // setSettings
  static const String setSettingsMethod = 'setSettings';
  static const String setSettingsCallbackOnComplete = 'setSettings_onComplete';
  static const String setSettingsCallbackOnError = 'setSettings_onError';

  // getSetting
  static const String getSettingMethod = 'getSetting';
  static const String getSettingCallbackOnResult = 'getSetting_onResult';
  static const String getSettingCallbackOnError = 'getSetting_onError';

  // getValueFor
  static const String getValueForMethod = 'getValueFor';
  static const String getValueForCallbackOnResult = 'getValueFor_onResult';
  static const String getValueForCallbackOnError = 'getValueFor_onError';

  // discoverBTClassic
  static const String discoverBTClassicMethod = 'discoverBTClassic';
  static const String discoverBTClassicCallbackOnComplete = 'discoverBTClassic_onComplete';
  static const String discoverBTClassicCallbackOnError = 'discoverBTClassic_onError';
  static const String discoverBTClassicEventPrinterFound = 'discoverBTClassic_printerFound';

  // discoverLocalBroadcast
  static const String discoverLocalBroadcastMethod = 'discoverLocalBroadcast';
  static const String discoverLocalBroadcastCallbackOnComplete = 'discoverLocalBroadcast_onComplete';
  static const String discoverLocalBroadcastCallbackOnError = 'discoverLocalBroadcast_onError';
  static const String discoverLocalBroadcastEventPrinterFound = 'discoverLocalBroadcast_printerFound';

  // discoverSubnet
  static const String discoverSubnetMethod = 'discoverSubnet';
  static const String discoverSubnetCallbackOnComplete = 'discoverSubnet_onComplete';
  static const String discoverSubnetCallbackOnError = 'discoverSubnet_onError';
  static const String discoverSubnetEventPrinterFound = 'discoverSubnet_printerFound';

  // discoverDirectedBroadcast
  static const String discoverDirectedBroadcastMethod = 'discoverDirectedBroadcast';
  static const String discoverDirectedBroadcastCallbackOnComplete = 'discoverDirectedBroadcast_onComplete';
  static const String discoverDirectedBroadcastCallbackOnError = 'discoverDirectedBroadcast_onError';
  static const String discoverDirectedBroadcastEventPrinterFound = 'discoverDirectedBroadcast_printerFound';

  // discoverMulticast
  static const String discoverMulticastMethod = 'discoverMulticast';
  static const String discoverMulticastCallbackOnComplete = 'discoverMulticast_onComplete';
  static const String discoverMulticastCallbackOnError = 'discoverMulticast_onError';
  static const String discoverMulticastEventPrinterFound = 'discoverMulticast_printerFound';

  // discovery generic log/warning event
  static const String discoveryEventLogWarning = 'discovery_logWarning';

  // stopScan
  static const String stopScanMethod = 'stopScan';
  static const String stopScanCallbackOnComplete = 'stopScan_onComplete';


  // getPrinterStatus
  static const String getPrinterStatusMethod = 'getPrinterStatus';
  static const String getPrinterStatusCallbackOnResult = 'getPrinterStatus_onResult';
  static const String getPrinterStatusCallbackOnError = 'getPrinterStatus_onError';

  // getDetailedPrinterStatus
  static const String getDetailedPrinterStatusMethod = 'getDetailedPrinterStatus';
  static const String getDetailedPrinterStatusCallbackOnResult = 'getDetailedPrinterStatus_onResult';
  static const String getDetailedPrinterStatusCallbackOnError = 'getDetailedPrinterStatus_onError';

  // Connection Events (unsolicited)
  static const String connectionEventStatusChanged = 'connection_statusChanged';
  static const String connectionEventLost = 'connection_lost';

  // General Callbacks
  static const String callbackOnMethodNotImplemented = 'onMethodNotImplemented';
}