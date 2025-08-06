import Flutter
import UIKit
import ExternalAccessory


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
            
        case "getPrinterStatus":
            getPrinterStatus(operationId: operationId, result: result)
        case "getDetailedPrinterStatus":
            getDetailedPrinterStatus(operationId: operationId, result: result)
            
        case "startNetworkDiscovery":
            startNetworkDiscovery(args: args, operationId: operationId, result: result)
            
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
        
        LogUtil.info("Starting printer discovery (MFi Bluetooth only)")
        
        // Start MFi Bluetooth discovery
        startMfiBluetoothDiscovery()
        
        result(true)
    }
    
    private func stopScan(operationId: String?, result: @escaping FlutterResult) {
        isScanning = false
        
        // Send completion event
        DispatchQueue.main.async {
            self.channel.invokeMethod("onDiscoveryDone", arguments: nil)
        }
        
        result(true)
    }
    
    private func startMfiBluetoothDiscovery() {
        // Discover MFi Bluetooth printers using External Accessory framework
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let accessoryManager = EAAccessoryManager.shared()
                let connectedAccessories = accessoryManager.connectedAccessories
                
                for accessory in connectedAccessories {
                    // Check if scanning is still active
                    guard self.isScanning else { break }
                    
                    // Check if this is a Zebra printer
                    if accessory.protocolStrings.contains("com.zebra.rawport") {
                        if let serialNumber = accessory.serialNumber, !serialNumber.isEmpty {
                            let printerInfo: [String: Any] = [
                                "Address": serialNumber,
                                "Name": accessory.name ?? "Zebra Printer",
                                "model": accessory.modelNumber ?? "",
                                "manufacturer": accessory.manufacturer ?? "",
                                "firmwareRevision": accessory.firmwareRevision ?? "",
                                "hardwareRevision": accessory.hardwareRevision ?? "",
                                "IsWifi": false,
                                "isBluetooth": true
                            ]
                            
                            // Send each printer as it's found (streaming)
                            DispatchQueue.main.async {
                                guard self.isScanning else { return }
                                self.channel.invokeMethod("printerFound", arguments: printerInfo)
                            }
                        }
                    }
                }
            } catch {
                LogUtil.error("MFi Bluetooth discovery error: \(error)")
            }
        }
    }
    
    // MARK: - Connection Operations
    
    private func connectToPrinter(address: String, operationId: String?, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Disconnect existing connection first
            self.disconnectInternal()
            
            // Parse address using simple logic (complex parsing is in Dart)
            let (parsedAddress, port) = self.parseAddress(address)
            let isNetworkDevice = parsedAddress.contains(".")
            
            LogUtil.info("Connecting to printer: \(parsedAddress):\(port), isNetwork: \(isNetworkDevice)")
            
            let connection = ZSDKWrapper.connect(toPrinter: parsedAddress, 
                                               port: port, 
                                               isBluetoothConnection: !isNetworkDevice)
            if connection != nil {
                self.connection = connection
                self.sendConnectionSuccess(operationId: operationId, result: result)
            } else {
                self.sendConnectionError(operationId: operationId, result: result)
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
            if let commandData = command.data(using: .utf8) {
                success = ZSDKWrapper.send(commandData, toConnection: connection)
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
                            additionalContext: ["operation": "setSettings", "command": command]
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
            
            let response = self.performSendAndRead(data: data, connection: connection, timeout: timeout)
            
            DispatchQueue.main.async {
                if let response = response {
                    result(response)
                } else {
                    result(FlutterError(code: "NO_RESPONSE", message: "No response from printer", details: nil))
                }
            }
        }
    }
    
    /// Perform send and read operation with timeout
    /// This orchestration logic moved from ZSDKWrapper to keep it Apple-specific
    private func performSendAndRead(data: String, connection: Any, timeout: Int) -> String? {
        guard let dataBytes = data.data(using: .utf8) else {
            LogUtil.error("Failed to encode data as UTF8")
            return nil
        }
        
        // Send the data using ZSDK connection
        let sendSuccess = ZSDKWrapper.sendData(dataBytes, toConnection: connection)
        if !sendSuccess {
            LogUtil.error("Failed to send data to printer")
            return nil
        }
        
        // Set connection timeout (Apple-specific connection handling)
        if let zsdkConnection = connection as? NSObject,
           zsdkConnection.responds(to: Selector(("setMaxTimeoutForRead:"))) {
            let timeoutValue = timeout > 0 ? timeout : 5000
            zsdkConnection.perform(Selector(("setMaxTimeoutForRead:")), with: timeoutValue)
        }
        
        // Read response using ZSDK connection
        // Note: This calls the simple ZSDK read method - the orchestration is here
        return ZSDKWrapper.readResponse(fromConnection: connection)
    }
    
    // MARK: - Helper Methods
    
    /// Parse address with optional port (simple version for iOS)
    /// For complex parsing, use Dart utilities in the business logic layer
    private func parseAddress(_ address: String) -> (address: String, port: Int) {
        let defaultPort = 9100
        
        if address.isEmpty {
            return (address, defaultPort)
        }
        
        let parts = address.split(separator: ":")
        if parts.count == 2,
           let portString = parts[1].trimmingCharacters(in: .whitespaces),
           let port = Int(portString) {
            let ip = String(parts[0]).trimmingCharacters(in: .whitespaces)
            return (ip, port)
        }
        
        return (address.trimmingCharacters(in: .whitespaces), defaultPort)
    }
    
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
    
    // MARK: - Printer Status Operations
    
    private func getPrinterStatus(operationId: String?, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let connection = self.connection {
                let status = ZSDKWrapper.getPrinterStatus(connection)
                
                DispatchQueue.main.async {
                    if let operationId = operationId {
                        self.channel.invokeMethod("onPrinterStatusResult", arguments: [
                            "operationId": operationId,
                            "status": status
                        ])
                    }
                    result(status)
                }
            } else {
                DispatchQueue.main.async {
                    let errorStatus: [String: Any] = [
                        "isReadyToPrint": false,
                        "isHeadOpen": false,
                        "isPaperOut": false,
                        "isPaused": false,
                        "isRibbonOut": false,
                        "error": "No printer connection"
                    ]
                    
                    if let operationId = operationId {
                        self.channel.invokeMethod("onPrinterStatusResult", arguments: [
                            "operationId": operationId,
                            "status": errorStatus
                        ])
                    }
                    result(errorStatus)
                }
            }
        }
    }
    
    private func getDetailedPrinterStatus(operationId: String?, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let connection = self.connection {
                let detailedStatus = ZSDKWrapper.getDetailedPrinterStatus(connection)
                
                DispatchQueue.main.async {
                    if let operationId = operationId {
                        self.channel.invokeMethod("onDetailedPrinterStatusResult", arguments: [
                            "operationId": operationId,
                            "detailedStatus": detailedStatus
                        ])
                    }
                    result(detailedStatus)
                }
            } else {
                DispatchQueue.main.async {
                    let errorStatus: [String: Any] = [
                        "basicStatus": [
                            "isReadyToPrint": false,
                            "isHeadOpen": false,
                            "isPaperOut": false,
                            "isPaused": false,
                            "isRibbonOut": false,
                            "error": "No printer connection"
                        ],
                        "canPrint": false,
                        "blockingIssues": [],
                        "recommendations": ["Check printer connection"]
                    ]
                    
                    if let operationId = operationId {
                        self.channel.invokeMethod("onDetailedPrinterStatusResult", arguments: [
                            "operationId": operationId,
                            "detailedStatus": errorStatus
                        ])
                    }
                    result(errorStatus)
                }
            }
        }
    }
}

private func startNetworkDiscovery(args: [String: Any]?, operationId: String?, result: @escaping FlutterResult) {
    let timeout = args?["timeout"] as? Int ?? 5000
    let customSubnets = args?["customSubnets"] as? [String] ?? []
    
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        guard let self = self else { return }
        
        var allPrinters: [[String: Any]] = []
        
        // Local broadcast
        var error: NSError?
        let localPrinters = ZSDKWrapper.discoverLocalPrinters(withTimeout: timeout, error: &error)
        if let dicts = ZSDKWrapper.convertDiscoveredPrinters(toDict: localPrinters) as? [[String: Any]] {
            allPrinters.append(contentsOf: dicts)
        }
        
        // HotSpot subnet (172.20.10.1-254)
        let hotspotPrinters = ZSDKWrapper.discoverSubnetPrinters(withRange: "172.20.10.*", timeout: timeout, error: &error)
        if let dicts = ZSDKWrapper.convertDiscoveredPrinters(toDict: hotspotPrinters) as? [[String: Any]] {
            allPrinters.append(contentsOf: dicts)
        }
        
        // Custom subnets
        for subnet in customSubnets {
            let customPrinters = ZSDKWrapper.discoverSubnetPrinters(withRange: "\(subnet).*", timeout: timeout, error: &error)
            if let dicts = ZSDKWrapper.convertDiscoveredPrinters(toDict: customPrinters) as? [[String: Any]] {
                allPrinters.append(contentsOf: dicts)
            }
        }
        
        // Stream results to Dart
        DispatchQueue.main.async {
            for printer in allPrinters {
                self.channel.invokeMethod("printerFound", arguments: printer)
            }
            if let operationId = operationId {
                self.channel.invokeMethod("onDiscoveryComplete", arguments: ["operationId": operationId])
            }
            result(true)
        }
    }
}


