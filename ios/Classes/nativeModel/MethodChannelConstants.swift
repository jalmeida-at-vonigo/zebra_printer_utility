import Foundation

/// Constants for all method channel communication between native and Dart
/// This must be kept in sync with Dart method_channel_constants.dart
@objc public class MethodChannelConstants: NSObject {
    
    // MARK: - Channel Names
    @objc public static let mainChannel = "zebrautil"
    
    // MARK: - getInstance
    @objc public static let getInstanceMethod = "getInstance"
    
    // MARK: - connectToPrinter
    @objc public static let connectToPrinterMethod = "connectToPrinter"
    @objc public static let connectToPrinterCallbackOnComplete = "connectToPrinter_onComplete"
    @objc public static let connectToPrinterCallbackOnError = "connectToPrinter_onError"
    
    // MARK: - disconnect
    @objc public static let disconnectMethod = "disconnect"
    @objc public static let disconnectCallbackOnComplete = "disconnect_onComplete"
    @objc public static let disconnectCallbackOnError = "disconnect_onError"
    
    // MARK: - isConnected
    @objc public static let isConnectedMethod = "isConnected"
    @objc public static let isConnectedCallbackOnResult = "isConnected_onResult"
    
    // MARK: - print
    @objc public static let printMethod = "print"
    @objc public static let printCallbackOnComplete = "print_onComplete"
    @objc public static let printCallbackOnError = "print_onError"
    @objc public static let printEventStatusUpdate = "print_statusUpdate"
    @objc public static let printEventProgressUpdate = "print_progressUpdate"
    
    // MARK: - setSettings
    @objc public static let setSettingsMethod = "setSettings"
    @objc public static let setSettingsCallbackOnComplete = "setSettings_onComplete"
    @objc public static let setSettingsCallbackOnError = "setSettings_onError"
    
    // MARK: - getSetting
    @objc public static let getSettingMethod = "getSetting"
    @objc public static let getSettingCallbackOnResult = "getSetting_onResult"
    @objc public static let getSettingCallbackOnError = "getSetting_onError"
    
    // MARK: - getValueFor
    @objc public static let getValueForMethod = "getValueFor"
    @objc public static let getValueForCallbackOnResult = "getValueFor_onResult"
    @objc public static let getValueForCallbackOnError = "getValueFor_onError"
    
    // MARK: - discoverBTClassic
    @objc public static let discoverBTClassicMethod = "discoverBTClassic"
    @objc public static let discoverBTClassicCallbackOnComplete = "discoverBTClassic_onComplete"
    @objc public static let discoverBTClassicCallbackOnError = "discoverBTClassic_onError"
    @objc public static let discoverBTClassicEventPrinterFound = "discoverBTClassic_printerFound"
    
    // MARK: - discoverLocalBroadcast
    @objc public static let discoverLocalBroadcastMethod = "discoverLocalBroadcast"
    @objc public static let discoverLocalBroadcastCallbackOnComplete = "discoverLocalBroadcast_onComplete"
    @objc public static let discoverLocalBroadcastCallbackOnError = "discoverLocalBroadcast_onError"
    @objc public static let discoverLocalBroadcastEventPrinterFound = "discoverLocalBroadcast_printerFound"
    
    // MARK: - discoverSubnet
    @objc public static let discoverSubnetMethod = "discoverSubnet"
    @objc public static let discoverSubnetCallbackOnComplete = "discoverSubnet_onComplete"
    @objc public static let discoverSubnetCallbackOnError = "discoverSubnet_onError"
    @objc public static let discoverSubnetEventPrinterFound = "discoverSubnet_printerFound"
    
    // MARK: - discoverDirectedBroadcast
    @objc public static let discoverDirectedBroadcastMethod = "discoverDirectedBroadcast"
    @objc public static let discoverDirectedBroadcastCallbackOnComplete = "discoverDirectedBroadcast_onComplete"
    @objc public static let discoverDirectedBroadcastCallbackOnError = "discoverDirectedBroadcast_onError"
    @objc public static let discoverDirectedBroadcastEventPrinterFound = "discoverDirectedBroadcast_printerFound"
    
    // MARK: - discoverMulticast
    @objc public static let discoverMulticastMethod = "discoverMulticast"
    @objc public static let discoverMulticastCallbackOnComplete = "discoverMulticast_onComplete"
    @objc public static let discoverMulticastCallbackOnError = "discoverMulticast_onError"
    @objc public static let discoverMulticastEventPrinterFound = "discoverMulticast_printerFound"
    
    // MARK: - Discovery log/warning event
    @objc public static let discoveryEventLogWarning = "discovery_logWarning"
    
    // MARK: - stopScan
    @objc public static let stopScanMethod = "stopScan"
    @objc public static let stopScanCallbackOnComplete = "stopScan_onComplete"
    
    
    // MARK: - getPrinterStatus
    @objc public static let getPrinterStatusMethod = "getPrinterStatus"
    @objc public static let getPrinterStatusCallbackOnResult = "getPrinterStatus_onResult"
    @objc public static let getPrinterStatusCallbackOnError = "getPrinterStatus_onError"
    
    // MARK: - getDetailedPrinterStatus
    @objc public static let getDetailedPrinterStatusMethod = "getDetailedPrinterStatus"
    @objc public static let getDetailedPrinterStatusCallbackOnResult = "getDetailedPrinterStatus_onResult"
    @objc public static let getDetailedPrinterStatusCallbackOnError = "getDetailedPrinterStatus_onError"
    
    // MARK: - Connection Events (unsolicited)
    @objc public static let connectionEventStatusChanged = "connection_statusChanged"
    @objc public static let connectionEventLost = "connection_lost"
    
    // MARK: - General Callbacks
    @objc public static let callbackOnMethodNotImplemented = "onMethodNotImplemented"
}