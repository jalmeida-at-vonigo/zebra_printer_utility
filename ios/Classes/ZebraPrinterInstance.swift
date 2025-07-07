import Flutter
import UIKit
#if canImport(Network)
import Network
#endif

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
    
    // Network discovery
#if canImport(Network)
    private var networkBrowser: Any?
    private var networkResults: [Any] = []
#else
    private var networkBrowser: Any?
    private var networkResults: [Any] = []
#endif
    
    // MFi Bluetooth discovery
    private var discoveredMfiPrinters: [[String: Any]] = []
    
    init(instanceId: String, registrar: FlutterPluginRegistrar) {
        self.instanceId = instanceId
        self.channel = FlutterMethodChannel(
            name: "ZebraPrinterObject\(instanceId)",
            binaryMessenger: registrar.messenger()
        )
        
        super.init()
        
        self.channel.setMethodCallHandler(self.handle)
    }
    
    // MARK: - Error Enrichment Helper
    
    private func createEnrichedError(
        message: String,
        code: String,
        operationId: String?,
        nativeError: Error? = nil,
        additionalContext: [String: Any]? = nil
    ) -> [String: Any] {
        var errorInfo: [String: Any] = [
            "message": message,
            "code": code,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "nativeStackTrace": Thread.callStackSymbols.joined(separator: "\n"),
            "operationId": operationId ?? "unknown",
            "instanceId": instanceId,
            "queue": Thread.isMainThread ? "main" : "background"
        ]
        
        if let nativeError = nativeError {
            errorInfo["nativeError"] = nativeError.localizedDescription
            errorInfo["nativeErrorCode"] = (nativeError as NSError).code
            errorInfo["nativeErrorDomain"] = (nativeError as NSError).domain
            errorInfo["nativeErrorUserInfo"] = (nativeError as NSError).userInfo
        }
        
        if let additionalContext = additionalContext {
            errorInfo["context"] = additionalContext
        }
        
        return errorInfo
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
            // For MFi Bluetooth, we don't need special permissions
            // The system handles MFi accessory permissions automatically
            let bluetoothAvailable = true
            
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
        isScanning = true
        discoveredPrinters.removeAll()
        discoveredMfiPrinters.removeAll()
        networkResults.removeAll()
        
        LogUtil.info("Starting printer discovery (Network and MFi Bluetooth)")
        
        // Start network discovery immediately (no permission required)
        startNetworkDiscovery()
        
        // Start MFi Bluetooth discovery
        startMfiBluetoothDiscovery()
        
        result(true)
    }
    
    private func startNetworkDiscovery() {
        #if canImport(Network)
        if #available(iOS 13.0, *) {
            // Create network browser for printer services
            let parameters = NWParameters()
            parameters.includePeerToPeer = true
            
            let browser = NWBrowser(for: .bonjour(type: "_printer._tcp", domain: nil), using: parameters)
            browser.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    LogUtil.info("Network browser ready")
                case .failed(let error):
                    LogUtil.error("Network browser failed: \(error)")
                default:
                    break
                }
            }
            
            browser.browseResultsChangedHandler = { [weak self] results, changes in
                if #available(iOS 13.0, *) {
                    self?.handleNetworkResults(results)
                }
            }
            
            networkBrowser = browser
            browser.start(queue: DispatchQueue.global())
        } else {
            LogUtil.warn("Network discovery not available on iOS < 13.0")
        }
        #else
        LogUtil.warn("Network framework not available")
        #endif
    }
    
#if canImport(Network)
    @available(iOS 13.0, *)
    private func handleNetworkResults(_ results: Set<NWBrowser.Result>) {
        networkResults = Array(results)
        for result in results {
            if case let .service(name: name, type: type, domain: domain, interface: interface) = result.endpoint {
                // For network discovery, use the service name as address or extract from endpoint
                let address = name.contains(":") ? name : "\(name).local"
                let printerInfo: [String: Any] = [
                    "address": address,
                    "name": name,
                    "status": "Found",
                    "isWifi": true,
                    "type": type,
                    "domain": domain ?? ""
                ]
                DispatchQueue.main.async {
                    self.channel.invokeMethod("printerFound", arguments: printerInfo)
                }
            }
        }
    }
    
    private func handleNetworkResults(_ results: Any) {
        // No-op for iOS < 13
    }
#else
    private func handleNetworkResults(_ results: Any) {
        // No-op when Network framework is not available
    }
#endif
    
    private func stopScan(operationId: String?, result: @escaping FlutterResult) {
        isScanning = false
        
        // Stop network discovery
        #if canImport(Network)
        if #available(iOS 13.0, *) {
            if let browser = networkBrowser as? NWBrowser {
                browser.cancel()
            }
            networkBrowser = nil
        }
        #endif
        
        // Send completion event
        DispatchQueue.main.async {
            self.channel.invokeMethod("onDiscoveryDone", arguments: nil)
        }
        
        result(true)
    }
    
    private func startMfiBluetoothDiscovery() {
        // Use ZSDK to discover MFi Bluetooth printers
        ZSDKWrapper.startMfiBluetoothDiscovery { [weak self] printers in
            DispatchQueue.main.async {
                if let printers = printers {
                    for printer in printers {
                        self?.channel.invokeMethod("printerFound", arguments: printer)
                    }
                }
            }
        } error: { [weak self] error in
            LogUtil.error("MFi Bluetooth discovery error: \(error)")
        }
    }
    
    // MARK: - Connection Operations
    
    private func connectToPrinter(address: String, operationId: String?, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Disconnect existing connection first
            self.disconnectInternal()
            
            // Determine if it's network based on address format
            let isNetworkDevice = address.contains(".") || address.contains(":")
            
            LogUtil.info("Connecting to printer: \(address), isNetwork: \(isNetworkDevice)")
            
            if isNetworkDevice {
                // Network connection
                let connection = ZSDKWrapper.connect(toPrinter: address, isBluetoothConnection: false)
                if connection != nil {
                    self.connection = connection
                    self.sendConnectionSuccess(operationId: operationId, result: result)
                } else {
                    self.sendConnectionError(operationId: operationId, result: result)
                }
            } else {
                // MFi Bluetooth connection
                let connection = ZSDKWrapper.connect(toPrinter: address, isBluetoothConnection: true)
                if connection != nil {
                    self.connection = connection
                    self.sendConnectionSuccess(operationId: operationId, result: result)
                } else {
                    self.sendConnectionError(operationId: operationId, result: result)
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
            
            DispatchQueue.main.async {
                if let operationId = operationId {
                    self?.channel.invokeMethod("onDisconnectComplete", arguments: [
                        "operationId": operationId
                    ])
                }
                result(true)
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
                        let enrichedError = self?.createEnrichedError(
                            message: "Not connected to printer",
                            code: "PRINT_ERROR",
                            operationId: operationId,
                            additionalContext: ["operation": "print", "dataLength": data.count]
                        )
                        self?.channel.invokeMethod("onPrintError", arguments: enrichedError ?? [:])
                    }
                    // Don't return FlutterError when using callback pattern - let the callback handle the error
                    result(false)
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
                        Thread.sleep(forTimeInterval: 1.0)
                    }
                    
                    DispatchQueue.main.async {
                        if let operationId = operationId {
                            self.channel.invokeMethod("onPrintComplete", arguments: [
                                "operationId": operationId
                            ])
                        }
                        self.channel.invokeMethod("changePrinterStatus", arguments: [
                            "Status": "Done",
                            "Color": "G"
                        ])
                        result(true)
                    }
                } else {
                    let errorMsg = "Failed to send data to printer"
                    DispatchQueue.main.async {
                        if let operationId = operationId {
                            let enrichedError = self.createEnrichedError(
                                message: errorMsg,
                                code: "PRINT_ERROR",
                                operationId: operationId,
                                additionalContext: ["operation": "print", "dataLength": data.count, "dataPreview": String(data.prefix(100))]
                            )
                            self.channel.invokeMethod("onPrintError", arguments: enrichedError)
                        }
                        self.channel.invokeMethod("changePrinterStatus", arguments: [
                            "Status": "Print Error: \(errorMsg)",
                            "Color": "R"
                        ])
                        // Don't return FlutterError when using callback pattern - let the callback handle the error
                        result(false)
                    }
                }
            } else {
                let errorMsg = "Invalid data encoding"
                DispatchQueue.main.async {
                    if let operationId = operationId {
                        let enrichedError = self.createEnrichedError(
                            message: errorMsg,
                            code: "PRINT_ERROR",
                            operationId: operationId,
                            additionalContext: ["operation": "print", "dataLength": data.count, "encodingIssue": true]
                        )
                        self.channel.invokeMethod("onPrintError", arguments: enrichedError)
                    }
                    // Don't return FlutterError when using callback pattern - let the callback handle the error
                    result(false)
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
                    // Don't return FlutterError when using callback pattern - let the callback handle the error
                    result(false)
                }
                return
            }
            
            var success = false
            
            if command.contains("=") {
                let components = command.components(separatedBy: "=")
                if components.count == 2 {
                    success = ZSDKWrapper.setSetting(components[0], value: components[1], onConnection: connection)
                }
            } else {
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
                    result(true)
                } else {
                    if let operationId = operationId {
                        let enrichedError = self.createEnrichedError(
                            message: "Failed to set printer settings",
                            code: "SETTINGS_ERROR",
                            operationId: operationId,
                            additionalContext: ["operation": "setSettings", "command": command, "commandType": command.contains("=") ? "keyValue" : "raw"]
                        )
                        self.channel.invokeMethod("onSettingsError", arguments: enrichedError)
                    }
                    // Don't return FlutterError when using callback pattern - let the callback handle the error
                    result(false)
                }
            }
        }
    }
    
    private func getLocateValue(key: String, operationId: String?, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
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
                    // Don't return FlutterError when using callback pattern - let the callback handle the error
                    result(false)
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
                    // Don't return FlutterError when using callback pattern - let the callback handle the error
                    result(false)
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
    
    // MARK: - Helper Methods
    
    private func sendConnectionSuccess(operationId: String?, result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            if let operationId = operationId {
                self.channel.invokeMethod("onConnectComplete", arguments: [
                    "operationId": operationId
                ])
            }
            result(true)
        }
    }
    
    private func sendConnectionError(operationId: String?, result: @escaping FlutterResult, nativeError: Error? = nil, context: [String: Any]? = nil) {
        DispatchQueue.main.async {
            if let operationId = operationId {
                let enrichedError = self.createEnrichedError(
                    message: "Failed to connect to printer",
                    code: "CONNECTION_ERROR",
                    operationId: operationId,
                    nativeError: nativeError,
                    additionalContext: context
                )
                self.channel.invokeMethod("onConnectError", arguments: enrichedError)
            }
            // Don't return FlutterError when using callback pattern - let the callback handle the error
            result(false)
        }
    }
}

// MARK: - MFi Bluetooth Discovery

extension ZebraPrinterInstance {
    // MFi Bluetooth discovery is handled by ZSDKWrapper
}
