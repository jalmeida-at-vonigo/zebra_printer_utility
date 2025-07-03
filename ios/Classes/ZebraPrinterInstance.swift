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
        // Extract operationId if present
        let args = call.arguments as? [String: Any]
        let operationId = args?["operationId"] as? String
        
        switch call.method {
        case "checkPermission":
            checkPermission(operationId: operationId, result: result)
            
        case "startScan", "discoverPrinters":
            startScan(call: call, operationId: operationId, result: result)
            
        case "stopScan":
            stopScan(operationId: operationId, result: result)
            
        case "connectToPrinter":
            if let address = args?["Address"] as? String {
                connectToPrinter(address: address, operationId: operationId, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Address is required", details: nil))
            }
            
        case "connectToGenericPrinter":
            if let address = args?["Address"] as? String {
                connectToGenericPrinter(address: address, operationId: operationId, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Address is required", details: nil))
            }
            
                    case "print":
            if let data = args?["Data"] as? String {
                printData(data: data, operationId: operationId, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Data is required", details: nil))
                }
            
        case "disconnect":
            disconnect(operationId: operationId, result: result)
            
        case "isPrinterConnected":
            isPrinterConnected(operationId: operationId, result: result)
            
        case "setSettings":
            if let command = args?["SettingCommand"] as? String {
                setSettings(command: command, operationId: operationId, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "SettingCommand is required", details: nil))
            }
            
        case "getLocateValue":
            if let key = args?["ResourceKey"] as? String {
                getLocateValue(key: key, operationId: operationId, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "ResourceKey is required", details: nil))
            }
            
        case "getSetting":
            if let setting = args?["setting"] as? String {
                getSetting(setting: setting, operationId: operationId, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "setting is required", details: nil))
            }
            
        case "sendDataWithResponse":
            if let data = args?["data"] as? String,
               let timeout = args?["timeout"] as? Int {
                sendDataWithResponse(data: data, timeout: timeout, operationId: operationId, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "data and timeout are required", details: nil))
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Permission Handling
    
    private func checkPermission(operationId: String?, result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            let bluetoothAvailable = EAAccessoryManager.shared().connectedAccessories.count >= 0
            
            // Send callback with operation ID
            if let operationId = operationId {
                self.channel.invokeMethod("onPermissionResult", arguments: [
                    "operationId": operationId,
                    "granted": bluetoothAvailable
                ])
            }
            
            result(bluetoothAvailable)
        }
    }
    
    // MARK: - Discovery Operations
    
    private func startScan(call: FlutterMethodCall, operationId: String?, result: @escaping FlutterResult) {
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
                    DispatchQueue.main.async {
                    self.channel.invokeMethod("printerFound", arguments: [
                        "Address": info["address"] ?? "",
                        "Name": info["name"] ?? "Unknown Printer",
                        "Status": "Found",
                        "IsWifi": "false"
                    ])
                    }
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
                        DispatchQueue.main.async {
                        self.channel.invokeMethod("printerFound", arguments: [
                            "Address": info["address"] ?? "",
                            "Name": info["name"] ?? "Unknown Printer",
                            "Status": "Found",
                            "IsWifi": "true"
                        ])
                        }
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
            
            // Send completion event with operation ID
            LogUtil.info("Discovery completed - Bluetooth: \(bluetoothCompleted), Network: \(networkCompleted)")
            
            var arguments: [String: Any] = [:]
            if let operationId = operationId {
                arguments["operationId"] = operationId
            }
            
            if call.method == "discoverPrinters" {
                self.channel.invokeMethod("onPrinterDiscoveryDone", arguments: arguments)
            } else {
                self.channel.invokeMethod("onDiscoveryDone", arguments: arguments)
            }
            
            self.isScanning = false
            result(nil)
        }
    }
    
    private func stopScan(operationId: String?, result: @escaping FlutterResult) {
        ZSDKWrapper.stopDiscovery()
        
        // Send callback with operation ID
        if let operationId = operationId {
            DispatchQueue.main.async {
                self.channel.invokeMethod("onStopScanComplete", arguments: [
                    "operationId": operationId
                ])
            }
        }
        
        result(nil)
    }
    

    
    // MARK: - Connection Operations
    
    private func connectToPrinter(address: String, operationId: String?, result: @escaping FlutterResult) {
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
                
                // Send success callback with operation ID
                DispatchQueue.main.async {
                    if let operationId = operationId {
                        self.channel.invokeMethod("onConnectComplete", arguments: [
                            "operationId": operationId
                        ])
                    }
                    result(nil)
                }
            } else {
                // Send error callback with operation ID
                DispatchQueue.main.async {
                    if let operationId = operationId {
                        self.channel.invokeMethod("onConnectError", arguments: [
                            "operationId": operationId,
                            "error": "Failed to connect to printer"
                        ])
                    }
                    result(FlutterError(code: "CONNECTION_ERROR", message: "Failed to connect to printer", details: nil))
                }
            }
        }
    }
    
    private func connectToGenericPrinter(address: String, operationId: String?, result: @escaping FlutterResult) {
        connectToPrinter(address: address, operationId: operationId, result: result)
    }
    
    private func disconnect(operationId: String?, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            self?.disconnectInternal()
            
            // Send callback with operation ID
            DispatchQueue.main.async {
                if let operationId = operationId {
                    self?.channel.invokeMethod("onDisconnectComplete", arguments: [
                        "operationId": operationId
                    ])
                }
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
    
    private func isPrinterConnected(operationId: String?, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            let isConnected = self?.connection != nil && ZSDKWrapper.isConnected(self?.connection)
            
            // Send callback with operation ID
            DispatchQueue.main.async {
                if let operationId = operationId {
                    self?.channel.invokeMethod("onConnectionStatusResult", arguments: [
                        "operationId": operationId,
                        "connected": isConnected
                    ])
                }
                result(isConnected)
            }
        }
    }
    
    // MARK: - Printing Operations
    
    private func printData(data: String, operationId: String?, result: @escaping FlutterResult) {
        printQueue.async { [weak self] in
            guard let self = self, let connection = self.connection else {
                DispatchQueue.main.async {
                    if let operationId = operationId {
                        self?.channel.invokeMethod("onPrintError", arguments: [
                            "operationId": operationId,
                            "error": "Not connected to printer",
                            "ErrorText": "Not connected to printer"
                        ])
                    } else {
                    self?.channel.invokeMethod("onPrintError", arguments: [
                        "ErrorText": "Not connected to printer"
                    ])
                    }
                    result(FlutterError(code: "PRINT_ERROR", message: "Not connected to printer", details: nil))
                }
                return
            }
            
            // Update status
            DispatchQueue.main.async {
                self.channel.invokeMethod("changePrinterStatus", arguments: [
                    "Status": "Sending Data",
                    "Color": "Y"
                ])
            }
            
            if let dataBytes = data.data(using: .utf8) {
                    let success = ZSDKWrapper.send(dataBytes, toConnection: connection)
                    
                    if success {
                    // For CPCL data, add extra delay to ensure complete transmission
                    if data.hasPrefix("!") || data.contains("! 0") {
                        // CPCL detected - wait longer to ensure all data is sent
                        // Based on Zebra forum findings, CPCL needs more time
                        Thread.sleep(forTimeInterval: 1.0)
                    }
                    
                    // Send success callback with operation ID
                        DispatchQueue.main.async {
                        if let operationId = operationId {
                            self.channel.invokeMethod("onPrintComplete", arguments: [
                                "operationId": operationId
                            ])
                        } else {
                            self.channel.invokeMethod("onPrintComplete", arguments: nil)
                        }
                            self.channel.invokeMethod("changePrinterStatus", arguments: [
                                "Status": "Done",
                                "Color": "G"
                            ])
                            result(nil)
                        }
                    } else {
                        let errorMsg = "Failed to send data to printer"
                        DispatchQueue.main.async {
                        if let operationId = operationId {
                            self.channel.invokeMethod("onPrintError", arguments: [
                                "operationId": operationId,
                                "error": errorMsg,
                                "ErrorText": errorMsg
                            ])
                        } else {
                            self.channel.invokeMethod("onPrintError", arguments: [
                                "ErrorText": errorMsg
                            ])
                        }
                            self.channel.invokeMethod("changePrinterStatus", arguments: [
                                "Status": "Print Error: \(errorMsg)",
                                "Color": "R"
                            ])
                            result(FlutterError(code: "PRINT_ERROR", message: errorMsg, details: nil))
                        }
                    }
            } else {
                let errorMsg = "Invalid data encoding"
                    DispatchQueue.main.async {
                    if let operationId = operationId {
                        self.channel.invokeMethod("onPrintError", arguments: [
                            "operationId": operationId,
                            "error": errorMsg,
                            "ErrorText": errorMsg
                        ])
            } else {
                    self.channel.invokeMethod("onPrintError", arguments: [
                        "ErrorText": errorMsg
                    ])
                    }
                    result(FlutterError(code: "PRINT_ERROR", message: errorMsg, details: nil))
                }
            }
        }
    }
    
    // MARK: - Settings Operations
    
    private func setSettings(command: String, operationId: String?, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            guard let self = self, let connection = self.connection else {
                DispatchQueue.main.async {
                    if let operationId = operationId {
                        self?.channel.invokeMethod("onSettingsError", arguments: [
                            "operationId": operationId,
                            "error": "Not connected to printer"
                        ])
                    }
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
                    if let operationId = operationId {
                        self.channel.invokeMethod("onSettingsComplete", arguments: [
                            "operationId": operationId
                        ])
                    }
                    result(nil)
                } else {
                    if let operationId = operationId {
                        self.channel.invokeMethod("onSettingsError", arguments: [
                            "operationId": operationId,
                            "error": "Failed to set printer settings"
                        ])
                    }
                    result(FlutterError(code: "SETTINGS_ERROR", message: "Failed to set printer settings", details: nil))
                }
            }
        }
    }
    
    private func getLocateValue(key: String, operationId: String?, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            // Special handling for localized values
            if key == "connected" {
                DispatchQueue.main.async {
                    if let operationId = operationId {
                        self?.channel.invokeMethod("onLocateValueResult", arguments: [
                            "operationId": operationId,
                            "value": "Connected"
                        ])
                    }
                    result("Connected")
                }
                return
            }
            
            guard let self = self, let connection = self.connection else {
                DispatchQueue.main.async {
                    if let operationId = operationId {
                        self?.channel.invokeMethod("onSettingsError", arguments: [
                            "operationId": operationId,
                            "error": "Not connected to printer"
                        ])
                    }
                    result(FlutterError(code: "GET_VALUE_ERROR", message: "Not connected to printer", details: nil))
                }
                return
            }
            
            let value = ZSDKWrapper.getSetting(key, fromConnection: connection)
            DispatchQueue.main.async {
                if let operationId = operationId {
                    self.channel.invokeMethod("onLocateValueResult", arguments: [
                        "operationId": operationId,
                        "value": value ?? ""
                    ])
                }
                result(value ?? "")
            }
        }
    }
    
    // MARK: - New bi-directional communication methods
    
    private func getSetting(setting: String, operationId: String?, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            guard let self = self, let connection = self.connection else {
                DispatchQueue.main.async {
                    if let operationId = operationId {
                        self?.channel.invokeMethod("onSettingsError", arguments: [
                            "operationId": operationId,
                            "error": "Not connected to printer"
                        ])
                    }
                    result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to printer", details: nil))
                }
                return
            }
            
            let value = ZSDKWrapper.getSetting(setting, fromConnection: connection)
            DispatchQueue.main.async {
                if let operationId = operationId {
                    self.channel.invokeMethod("onSettingsResult", arguments: [
                        "operationId": operationId,
                        "value": value ?? ""
                    ])
                }
                result(value ?? "")
            }
        }
    }
    
    private func sendDataWithResponse(data: String, timeout: Int, operationId: String?, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            guard let self = self, let connection = self.connection else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to printer", details: nil))
                }
                return
            }
            
            // Send data and read response
            let response = ZSDKWrapper.sendAndReadResponse(data, 
                                                          toConnection: connection, 
                                                          withTimeout: timeout)
            
            DispatchQueue.main.async {
                if let response = response {
                    result(response)
                } else {
                    result(FlutterError(code: "NO_RESPONSE", message: "No response from printer", details: nil))
                }
            }
        }
    }
} 
