import Flutter
import UIKit
import ExternalAccessory
import CoreBluetooth

class ZebraPrinterInstance: NSObject {
    private let channel: FlutterMethodChannel
    private let instanceId: String
    private let connectionQueue = DispatchQueue(label: "com.zebrautil.connection", qos: .userInitiated)
    private let printQueue = DispatchQueue(label: "com.zebrautil.print", qos: .userInitiated)
    
    // ZSDK objects (stored as Any? to avoid exposing ZSDK types)
    private var connection: Any?
    
    // Discovery state
    private var isScanning = false
    private var discoveredPrinters: [[String: Any]] = []
    private var eventSink: FlutterEventSink?
    private var hasPermission = true // iOS doesn't need explicit Bluetooth permission for MFi devices
    
    init(instanceId: String, registrar: FlutterPluginRegistrar) {
        self.instanceId = instanceId
        self.channel = FlutterMethodChannel(
            name: "ZebraPrinterObject\(instanceId)",
            binaryMessenger: registrar.messenger()
        )
        
        super.init()
        
        self.channel.setMethodCallHandler(self.handle)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkPermission":
            checkPermission(result: result)
            
        case "startScan", "discoverPrinters":
            startScan(call: call, result: result)
            
        case "stopScan":
            stopScan(result: result)
            
        case "connectToPrinter":
            if let args = call.arguments as? [String: Any],
               let address = args["Address"] as? String {
                connectToPrinter(address: address, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Address is required", details: nil))
            }
            
        case "connectToGenericPrinter":
            if let args = call.arguments as? [String: Any],
               let address = args["Address"] as? String {
                connectToGenericPrinter(address: address, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Address is required", details: nil))
            }
            
        case "print":
            if let args = call.arguments as? [String: Any],
               let data = args["Data"] as? String {
                printData(data: data, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Data is required", details: nil))
            }
            
        case "disconnect":
            disconnect(result: result)
            
        case "isPrinterConnected":
            isPrinterConnected(result: result)
            
        case "setSettings":
            if let args = call.arguments as? [String: Any],
               let command = args["SettingCommand"] as? String {
                setSettings(command: command, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "SettingCommand is required", details: nil))
            }
            
        case "getLocateValue":
            if let args = call.arguments as? [String: Any],
               let key = args["ResourceKey"] as? String {
                getLocateValue(key: key, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "ResourceKey is required", details: nil))
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Permission Handling
    
    private func checkPermission(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            let bluetoothAvailable = EAAccessoryManager.shared().connectedAccessories.count >= 0
            result(bluetoothAvailable)
        }
    }
    
    // MARK: - Discovery Operations
    
    private func startScan(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard hasPermission else {
            result(FlutterError(code: "NO_PERMISSION", message: "Permission not granted", details: nil))
            return
        }
        
        isScanning = true
        discoveredPrinters.removeAll()
        
        LogUtil.info("Starting printer discovery")
        
        // Use dispatch group to coordinate parallel discovery
        let discoveryGroup = DispatchGroup()
        var bluetoothCompleted = false
        var networkCompleted = false
        
        // Start Bluetooth discovery
        discoveryGroup.enter()
        ZSDKWrapper.startBluetoothDiscovery({ [weak self] btPrinters in
            guard let self = self else { 
                discoveryGroup.leave()
                return 
            }
            
            for printerInfo in btPrinters {
                if let info = printerInfo as? [String: Any] {
                    self.channel.invokeMethod("printerFound", arguments: [
                        "Address": info["address"] ?? "",
                        "Name": info["name"] ?? "Unknown Printer",
                        "Status": "Found",
                        "IsWifi": "false"
                    ])
                }
            }
            
            LogUtil.info("Bluetooth discovery completed with \(btPrinters.count) printers")
            bluetoothCompleted = true
            discoveryGroup.leave()
        }, error: { [weak self] error in
            // Log error but don't stop the discovery process
            LogUtil.error("Bluetooth discovery error: \(error)")
            bluetoothCompleted = true
            discoveryGroup.leave()
        })
        
        // Start Network discovery in parallel
        discoveryGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            // Dummy connection to trigger network permission dialog
            if let dummyConnection = ZSDKWrapper.connect(toPrinter: "0.0.0.0", isBluetoothConnection: false) {
                ZSDKWrapper.disconnect(dummyConnection)
            }
            
            // Small delay to ensure permission dialog is handled
            Thread.sleep(forTimeInterval: 0.1)
            
            ZSDKWrapper.startNetworkDiscovery({ [weak self] networkPrinters in
                guard let self = self else { 
                    discoveryGroup.leave()
                    return 
                }
                
                for printerInfo in networkPrinters {
                    if let info = printerInfo as? [String: Any] {
                        self.channel.invokeMethod("printerFound", arguments: [
                            "Address": info["address"] ?? "",
                            "Name": info["name"] ?? "Unknown Printer",
                            "Status": "Found",
                            "IsWifi": "true"
                        ])
                    }
                }
                
                LogUtil.info("Network discovery completed with \(networkPrinters.count) printers")
                networkCompleted = true
                discoveryGroup.leave()
            }, error: { error in
                // Log error but don't stop the discovery process
                LogUtil.error("Network discovery error: \(error)")
                networkCompleted = true
                discoveryGroup.leave()
            })
        }
        
        // Wait for both discoveries to complete
        discoveryGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Send completion event
            LogUtil.info("Discovery completed - Bluetooth: \(bluetoothCompleted), Network: \(networkCompleted)")
            
            if call.method == "discoverPrinters" {
                self.channel.invokeMethod("onPrinterDiscoveryDone", arguments: nil)
            } else {
                self.channel.invokeMethod("onDiscoveryDone", arguments: nil)
            }
            
            self.isScanning = false
            result(nil)
        }
    }
    
    private func stopScan(result: @escaping FlutterResult) {
        ZSDKWrapper.stopDiscovery()
        result(nil)
    }
    

    
    // MARK: - Connection Operations
    
    private func connectToPrinter(address: String, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Disconnect existing connection first
            self.disconnectInternal()
            
            // Determine if it's Bluetooth based on address format (matching shashwatxx logic)
            let isBluetoothDevice = !address.contains(".")
            
            LogUtil.info("Connecting to printer: \(address), isBluetooth: \(isBluetoothDevice)")
            let connection = ZSDKWrapper.connect(toPrinter: address, isBluetoothConnection: isBluetoothDevice)
            if connection != nil {
                self.connection = connection
                
                DispatchQueue.main.async {
                    result(nil)
                }
            } else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "CONNECTION_ERROR", message: "Failed to connect to printer", details: nil))
                }
            }
        }
    }
    
    private func connectToGenericPrinter(address: String, result: @escaping FlutterResult) {
        connectToPrinter(address: address, result: result)
    }
    
    private func disconnect(result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            self?.disconnectInternal()
            DispatchQueue.main.async {
                result(nil)
            }
        }
    }
    
    private func disconnectInternal() {
        if let connection = connection {
            ZSDKWrapper.disconnect(connection)
            self.connection = nil
        }
    }
    
    private func isPrinterConnected(result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            let isConnected = self?.connection != nil && ZSDKWrapper.isConnected(self?.connection)
            DispatchQueue.main.async {
                result(isConnected)
            }
        }
    }
    
    // MARK: - Printing Operations
    
    private func printData(data: String, result: @escaping FlutterResult) {
        printQueue.async { [weak self] in
            guard let self = self, let connection = self.connection else {
                DispatchQueue.main.async {
                    self?.channel.invokeMethod("onPrintError", arguments: [
                        "ErrorText": "Not connected to printer"
                    ])
                    result(FlutterError(code: "PRINT_ERROR", message: "Not connected to printer", details: nil))
                }
                return
            }
            
            // Update status to sending
            DispatchQueue.main.async {
                self.channel.invokeMethod("changePrinterStatus", arguments: [
                    "Status": "Sending Data",
                    "Color": "Y"
                ])
            }
            
            if let dataBytes = data.data(using: .utf8) {
                let success = ZSDKWrapper.send(dataBytes, toConnection: connection)
                
                // Sleep for 1 second to match shashwatxx behavior
                Thread.sleep(forTimeInterval: 1)
                
                DispatchQueue.main.async {
                    if success {
                        // Send success callback
                        self.channel.invokeMethod("onPrintComplete", arguments: nil)
                        self.channel.invokeMethod("changePrinterStatus", arguments: [
                            "Status": "Done",
                            "Color": "G"
                        ])
                        result(nil)
                    } else {
                        // Send error callback
                        self.channel.invokeMethod("onPrintError", arguments: [
                            "ErrorText": "Failed to send data to printer"
                        ])
                        self.channel.invokeMethod("changePrinterStatus", arguments: [
                            "Status": "Print Error: Failed to send data to printer",
                            "Color": "R"
                        ])
                        result(FlutterError(code: "PRINT_ERROR", message: "Failed to print data", details: nil))
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.channel.invokeMethod("onPrintError", arguments: [
                        "ErrorText": "Invalid data encoding"
                    ])
                    result(FlutterError(code: "PRINT_ERROR", message: "Invalid data encoding", details: nil))
                }
            }
        }
    }
    
    // MARK: - Settings Operations
    
    private func setSettings(command: String, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            guard let self = self, let connection = self.connection else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SETTINGS_ERROR", message: "Not connected to printer", details: nil))
                }
                return
            }
            
            // Parse the command - it might be a raw SGD command or a setting=value pair
            var success = false
            
            if command.contains("=") {
                let components = command.components(separatedBy: "=")
                if components.count == 2 {
                    success = ZSDKWrapper.setSetting(components[0], value: components[1], onConnection: connection)
                }
            } else {
                // For raw commands, we'll need to send them directly
                if let commandData = command.data(using: .utf8) {
                    success = ZSDKWrapper.send(commandData, toConnection: connection)
                }
            }
            
            DispatchQueue.main.async {
                if success {
                    result(nil)
                } else {
                    result(FlutterError(code: "SETTINGS_ERROR", message: "Failed to set printer settings", details: nil))
                }
            }
        }
    }
    
    private func getLocateValue(key: String, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            // Special handling for localized values
            if key == "connected" {
                DispatchQueue.main.async {
                    result("Connected")
                }
                return
            }
            
            guard let self = self, let connection = self.connection else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "GET_VALUE_ERROR", message: "Not connected to printer", details: nil))
                }
                return
            }
            
            let value = ZSDKWrapper.getSetting(key, fromConnection: connection)
            DispatchQueue.main.async {
                result(value ?? "")
            }
        }
    }
} 
