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

    // Discovery cancellation management
    private var activeDiscoveryWorkItems: [DispatchWorkItem] = []
    private let discoveryQueue = DispatchQueue(label: "com.zebrautil.discovery", attributes: .concurrent)

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
        // Extract operationId - REQUIRED for all operations
        let args = call.arguments as? [String: Any]
        guard let operationId = args?["operationId"] as? String else {
            LogUtil.error("CRITICAL: Missing operationId in method call: \(call.method)")
            DispatchQueue.main.async {
                result(
                    FlutterError(
                        code: "ARCHITECTURE_ERROR",
                        message: "Operation manager pattern violation: missing operationId",
                        details: nil))
            }
            return
        }

        switch call.method {
        case "checkPermission":
            checkPermission(operationId: operationId, result: result)

        case "discoverBTClassic":
            discoverBTClassic(args: args, operationId: operationId, result: result)

        case "discoverLocalBroadcast":
            discoverLocalBroadcast(args: args, operationId: operationId, result: result)

        case "discoverSubnet":
            discoverSubnet(args: args, operationId: operationId, result: result)

        case "discoverDirectedBroadcast":
            discoverDirectedBroadcast(args: args, operationId: operationId, result: result)

        case "discoverMulticast":
            discoverMulticast(args: args, operationId: operationId, result: result)

        case "stopScan":
            stopScan(operationId: operationId, result: result)

        case "connectToPrinter":
            connectToPrinter(args: args, operationId: operationId, result: result)

        case "print":
            printData(args: args, operationId: operationId, result: result)

        case "disconnect":
            disconnect(operationId: operationId, result: result)

        case "isPrinterConnected":
            isPrinterConnected(operationId: operationId, result: result)

        case "setSettings":
            setSettings(args: args, operationId: operationId, result: result)

        case "getLocateValue":
            getLocateValue(args: args, operationId: operationId, result: result)

        case "getSetting":
            getSetting(args: args, operationId: operationId, result: result)

        case "getPrinterStatus":
            getPrinterStatus(operationId: operationId, result: result)

        case "getDetailedPrinterStatus":
            getDetailedPrinterStatus(operationId: operationId, result: result)

        default:
            _operationErrorResult(
                operationId: operationId,
                result: result,
                callbackMethod: "onMethodNotImplemented",
                code: "METHOD_NOT_IMPLEMENTED",
                message: "Method not implemented: \(call.method)")
        }
    }

    // MARK: - Permission Handling

    private func checkPermission(operationId: String, result: @escaping FlutterResult) {
        // For MFi Bluetooth, we don't need special permissions
        // The system handles MFi accessory permissions automatically
        let bluetoothAvailable = true

        // Use the original callback pattern for permission results
        self._operationSuccessResult(
            operationId: operationId,
            result: result,
            callbackMethod: "onPermissionResult",
            resultValue: bluetoothAvailable,
            arguments: ["granted": bluetoothAvailable]
        )
    }

    // MARK: - Discovery Operations

    // MARK: - Discovery Methods

    private func discoverBTClassic(args: [String: Any]?, operationId: String, result: @escaping FlutterResult) {
        let timeout = args?["timeout"] as? Int ?? 5000
        isScanning = true

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            var foundCount = 0

            // MFi Bluetooth discovery using External Accessory
            let accessoryManager = EAAccessoryManager.shared()
            let connectedAccessories = accessoryManager.connectedAccessories

            for accessory in connectedAccessories {
                // Check if cancelled or scanning stopped
                guard !workItem.isCancelled, self.isScanning else { break }

                // Check if this is a Zebra printer
                if accessory.protocolStrings.contains("com.zebra.rawport") {
                    if let serialNumber = accessory.serialNumber, !serialNumber.isEmpty {
                        // Create PrinterInfo object
                        let printerInfo = PrinterInfo(
                            address: serialNumber,
                            name: accessory.name ?? "Zebra Printer",
                            status: "Available",
                            isWifi: false,
                            isBluetooth: true,
                            connectionType: "bluetooth",
                            discoveryMethod: "btClassic",
                            model: accessory.modelNumber,
                            manufacturer: accessory.manufacturer,
                            firmwareRevision: accessory.firmwareRevision,
                            hardwareRevision: accessory.hardwareRevision
                        )

                        // Stream each printer as it's found
                        if self.isScanning {
                            DispatchQueue.main.async {
                                self.channel.invokeMethod("printerFound", arguments: printerInfo.toDictionary())
                            }
                        }
                        foundCount += 1
                    }
                }
            }

            // Remove work item when done
            DispatchQueue.main.async {
                self.activeDiscoveryWorkItems.removeAll { $0 === workItem }
            }

            // Complete operation properly - operationId is required
            if workItem.isCancelled {
                self._operationErrorResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onDiscoveryError",
                    code: "OPERATION_CANCELLED",
                    message: "Operation cancelled",
                    context: ["reason": "Operation cancelled"]
                )
            } else {
                self._operationSuccessResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onDiscoveryDone",
                    resultValue: true,
                    arguments: ["foundCount": foundCount]
                )
            }
        }

        // Store and execute work item
        activeDiscoveryWorkItems.append(workItem)
        discoveryQueue.async(execute: workItem)
    }

    private func discoverLocalBroadcast(args: [String: Any]?, operationId: String, result: @escaping FlutterResult) {
        let timeout = args?["timeout"] as? Int ?? 5000
        isScanning = true

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            var foundCount = 0

            do {
                var error: NSError?
                let printers = ZSDKWrapper.discoverLocalPrintersWithTimeout(timeout, error: &error)

                if let error = error {
                    self._operationErrorResult(
                        operationId: operationId,
                        result: result,
                        callbackMethod: "onDiscoveryError",
                        code: "DISCOVERY_ERROR",
                        message: "Local broadcast discovery failed",
                        nativeError: error,
                        context: ["method": "discoverLocalBroadcast"]
                    )
                    return
                }

                let printerInfos = self.convertNetworkPrinters(printers)
                // Stream each printer as it's found
                for printerInfo in printerInfos {
                    // Check if cancelled
                    guard !workItem.isCancelled, self.isScanning else { break }

                    // Override discovery method
                    var dict = printerInfo.toDictionary()
                    dict["discoveryMethod"] = "localBroadcast"

                    if self.isScanning {
                        DispatchQueue.main.async {
                            self.channel.invokeMethod("printerFound", arguments: dict)
                        }
                    }
                    foundCount += 1
                }

                // Remove work item when done
                DispatchQueue.main.async {
                    self.activeDiscoveryWorkItems.removeAll { $0 === workItem }
                }

                // Complete operation properly - operationId is required
                if workItem.isCancelled {
                    self._operationErrorResult(
                        operationId: operationId,
                        result: result,
                        callbackMethod: "onDiscoveryError",
                        code: "OPERATION_CANCELLED",
                        message: "Operation cancelled",
                        context: ["reason": "Operation cancelled"]
                    )
                } else {
                    self._operationSuccessResult(
                        operationId: operationId,
                        result: result,
                        callbackMethod: "onDiscoveryDone",
                        resultValue: true,
                        arguments: ["foundCount": foundCount])
                }

            } catch {
                self._operationErrorResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onDiscoveryError",
                    code: "DISCOVERY_ERROR",
                    message: "Local broadcast discovery failed",
                    nativeError: error as NSError,
                    context: ["method": "discoverLocalBroadcast"]
                )
            }
        }

        // Store and execute work item
        activeDiscoveryWorkItems.append(workItem)
        discoveryQueue.async(execute: workItem)
    }

    private func discoverSubnet(args: [String: Any]?, operationId: String, result: @escaping FlutterResult) {
        let timeout = args?["timeout"] as? Int ?? 5000
        let subnet = args?["subnet"] as? String ?? "192.168.1"
        isScanning = true

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            var foundCount = 0

            // Build subnet ranges including iPad hotspot
            let ranges = [
                "\(subnet).*",      // User specified subnet
                "172.20.10.*"       // iPad hotspot subnet
            ]

            for range in ranges {
                // Check if cancelled
                guard !workItem.isCancelled, self.isScanning else { break }

                var error: NSError?
                let printers = ZSDKWrapper.discoverSubnetPrintersWithRange(range, timeout: timeout, error: &error)

                if error == nil {
                    let printerInfos = self.convertNetworkPrinters(printers)
                    for printerInfo in printerInfos {
                        // Check if cancelled
                        guard !workItem.isCancelled, self.isScanning else { break }

                        // Override discovery method
                        var dict = printerInfo.toDictionary()
                        dict["discoveryMethod"] = "subnet"

                        if self.isScanning {
                            DispatchQueue.main.async {
                                self.channel.invokeMethod("printerFound", arguments: dict)
                            }
                        }
                        foundCount += 1
                    }
                }
            }

            // Remove work item when done
            DispatchQueue.main.async {
                self.activeDiscoveryWorkItems.removeAll { $0 === workItem }
            }

            // Complete operation properly - operationId is required
            if workItem.isCancelled {
                self._operationErrorResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onDiscoveryError",
                    code: "OPERATION_CANCELLED",
                    message: "Operation cancelled",
                    context: ["reason": "Operation cancelled"]
                )
            } else {
                self._operationSuccessResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onDiscoveryDone",
                    resultValue: true,
                    arguments: ["foundCount": foundCount]
                )
            }
        }

        // Store and execute work item
        activeDiscoveryWorkItems.append(workItem)
        discoveryQueue.async(execute: workItem)
    }

    private func discoverDirectedBroadcast(args: [String: Any]?, operationId: String, result: @escaping FlutterResult) {
        let timeout = args?["timeout"] as? Int ?? 5000
        let ipAddress = args?["ipAddress"] as? String ?? "192.168.1.255"
        isScanning = true

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            var foundCount = 0

            // Build broadcast addresses including iPad hotspot
            let addresses = [
                ipAddress,          // User specified broadcast
                "172.20.10.255"     // iPad hotspot broadcast
            ]

            for address in addresses {
                // Check if cancelled
                guard !workItem.isCancelled, self.isScanning else { break }

                var error: NSError?
                let printers = ZSDKWrapper.discoverDirectedBroadcastWithIp(address, timeout: timeout, error: &error)

                if error == nil {
                    let printerInfos = self.convertNetworkPrinters(printers)
                    for printerInfo in printerInfos {
                        // Check if cancelled
                        guard !workItem.isCancelled, self.isScanning else { break }

                        // Override discovery method
                        var dict = printerInfo.toDictionary()
                        dict["discoveryMethod"] = "directedBroadcast"

                        if self.isScanning {
                            DispatchQueue.main.async {
                                self.channel.invokeMethod("printerFound", arguments: dict)
                            }
                        }
                        foundCount += 1
                    }
                }
            }

            // Remove work item when done
            DispatchQueue.main.async {
                self.activeDiscoveryWorkItems.removeAll { $0 === workItem }
            }

            // Complete operation properly - operationId is required
            if workItem.isCancelled {
                self._operationErrorResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onDiscoveryError",
                    code: "OPERATION_CANCELLED",
                    message: "Operation cancelled",
                    context: ["reason": "Operation cancelled"]
                )
            } else {
                self._operationSuccessResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onDiscoveryDone",
                    resultValue: true,
                    arguments: ["foundCount": foundCount]
                )
            }
        }

        // Store and execute work item
        activeDiscoveryWorkItems.append(workItem)
        discoveryQueue.async(execute: workItem)
    }

    private func discoverMulticast(args: [String: Any]?, operationId: String, result: @escaping FlutterResult) {
        let timeout = args?["timeout"] as? Int ?? 5000
        let hops = args?["hops"] as? Int ?? 5
        isScanning = true

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            var foundCount = 0

            var error: NSError?
            let printers = ZSDKWrapper.discoverMulticastWithHops(hops, timeout: timeout, error: &error)

            if let error = error {
                self._operationErrorResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onDiscoveryError",
                    code: "DISCOVERY_ERROR",
                    message: "Multicast discovery failed",
                    nativeError: error,
                    context: ["method": "discoverMulticast"]
                )
                return
            }

            let printerInfos = self.convertNetworkPrinters(printers)
            for printerInfo in printerInfos {
                // Check if cancelled
                guard !workItem.isCancelled, self.isScanning else { break }

                // Override discovery method
                var dict = printerInfo.toDictionary()
                dict["discoveryMethod"] = "multicast"

                if self.isScanning {
                    DispatchQueue.main.async {
                        self.channel.invokeMethod("printerFound", arguments: dict)
                    }
                }
                foundCount += 1
            }

            // Remove work item when done
            DispatchQueue.main.async {
                self.activeDiscoveryWorkItems.removeAll { $0 === workItem }
            }

            // Complete operation properly - operationId is required
            if workItem.isCancelled {
                self._operationErrorResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onDiscoveryError",
                    code: "OPERATION_CANCELLED",
                    message: "Operation cancelled",
                    context: ["reason": "Operation cancelled"]
                )
            } else {
                self._operationSuccessResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onDiscoveryDone",
                    resultValue: true,
                    arguments: ["foundCount": foundCount]
                )
            }
        }

        // Store and execute work item
        activeDiscoveryWorkItems.append(workItem)
        discoveryQueue.async(execute: workItem)
    }

    private func stopScan(operationId: String, result: @escaping FlutterResult) {
        isScanning = false

        // Cancel all active discovery operations
        for workItem in activeDiscoveryWorkItems {
            workItem.cancel()
        }
        activeDiscoveryWorkItems.removeAll()

        // Send completion event
        DispatchQueue.main.async {
            self.channel.invokeMethod("onDiscoveryStopped", arguments: nil)
        }

        // Complete the stopScan operation - operationId is required
        _operationSuccessResult(
            operationId: operationId,
            result: result,
            callbackMethod: "onStopScanComplete",
            resultValue: true
        )
    }

    // Helper to convert network printers to PrinterInfo
    private func convertNetworkPrinters(_ printers: [Any]?) -> [PrinterInfo] {
        guard let printers = printers else { return [] }

        return printers.compactMap { printer in
            guard let networkPrinter = printer as? NSObject,
                  networkPrinter.responds(to: Selector("address")),
                  let address = networkPrinter.value(forKey: "address") as? String,
                  !address.isEmpty else { return nil }

            let port = (networkPrinter.responds(to: Selector("port")) ?
                       networkPrinter.value(forKey: "port") as? Int : nil) ?? 9100
            let dnsName = networkPrinter.responds(to: Selector("dnsName")) ?
                         networkPrinter.value(forKey: "dnsName") as? String : nil

            return PrinterInfo(
                address: address,
                name: dnsName ?? address,
                status: "Available",
                isWifi: true,
                isBluetooth: false,
                connectionType: "network",
                discoveryMethod: "network", // Will be overridden by caller
                model: nil,
                manufacturer: "Zebra",
                firmwareRevision: nil,
                hardwareRevision: nil,
                displayName: nil,
                port: port,
                dnsName: dnsName
            )
        }
    }

    // MARK: - Connection Operations

    private func connectToPrinter(args: [String: Any]?, operationId: String, result: @escaping FlutterResult) {
        guard let address = args?["Address"] as? String else {
            _operationErrorResult(
                operationId: operationId,
                result: result,
                callbackMethod: "onConnectError",
                code: "INVALID_ARGUMENT",
                message: "Address is required")
            return
        }
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
                self._operationSuccessResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onConnectComplete",
                    resultValue: true
                )
            } else {
                self._operationErrorResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onConnectError",
                    code: "CONNECTION_ERROR",
                    message: "Failed to connect to printer"
                )
            }
        }
    }

    private func disconnect(operationId: String, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            self?.disconnectInternal()

            self?._operationSuccessResult(
                operationId: operationId,
                result: result,
                callbackMethod: "onDisconnectComplete",
                resultValue: true
            )
        }
    }

    private func disconnectInternal() {
        if let connection = connection {
            ZSDKWrapper.disconnect(connection)
            self.connection = nil
        }
    }

    private func isPrinterConnected(operationId: String, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            let isConnected = self?.connection != nil && ZSDKWrapper.isConnected(self?.connection)

            self?._operationSuccessResult(
                operationId: operationId,
                result: result,
                callbackMethod: "onConnectionStatusResult",
                resultValue: isConnected,
                arguments: ["connected": isConnected]
            )
        }
    }

    // MARK: - Printing Operations

    private func printData(args: [String: Any]?, operationId: String, result: @escaping FlutterResult) {
        guard let data = args?["Data"] as? String else {
            _operationErrorResult(
                operationId: operationId,
                result: result,
                callbackMethod: "onPrintError",
                code: "INVALID_ARGUMENT",
                message: "Data is required")
            return
        }
        printQueue.async { [weak self] in
            guard let self = self, let connection = self.connection else {
                self?._operationErrorResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onPrintError",
                    code: "PRINT_ERROR",
                    message: "Not connected to printer",
                    context: ["operation": "print", "dataLength": data.count]
                )
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
                        self.channel.invokeMethod("changePrinterStatus", arguments: [
                            "Status": "Done",
                            "Color": "G"
                        ])
                    }
                    self._operationSuccessResult(
                        operationId: operationId,
                        result: result,
                        callbackMethod: "onPrintComplete",
                        resultValue: true
                    )
                } else {
                    let errorMsg = "Failed to send data to printer"
                    DispatchQueue.main.async {
                        self.channel.invokeMethod("changePrinterStatus", arguments: [
                            "Status": "Print Error: \(errorMsg)",
                            "Color": "R"
                        ])
                    }
                    self._operationErrorResult(
                        operationId: operationId,
                        result: result,
                        callbackMethod: "onPrintError",
                        code: "PRINT_ERROR",
                        message: errorMsg,
                        context: ["operation": "print", "dataLength": data.count, "dataPreview": String(data.prefix(100))]
                    )
                }
            } else {
                let errorMsg = "Invalid data encoding"
                self._operationErrorResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onPrintError",
                    code: "PRINT_ERROR",
                    message: errorMsg,
                    context: ["operation": "print", "dataLength": data.count, "encodingIssue": true]
                )
            }
        }
    }

    // MARK: - Settings Operations

    private func setSettings(args: [String: Any]?, operationId: String, result: @escaping FlutterResult) {
        guard let command = args?["SettingCommand"] as? String else {
            _operationErrorResult(
                operationId: operationId, 
                result: result, 
                callbackMethod: "onSettingsError",
                code: "INVALID_ARGUMENT", 
                message: "SettingCommand is required")
            return
        }
        connectionQueue.async { [weak self] in
            guard let self = self, let connection = self.connection else {
                self?._operationErrorResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onSettingsError",
                    code: "CONNECTION_ERROR",
                    message: "Not connected to printer",
                    arguments: ["error": "Not connected to printer"]
                )
                return
            }

            var success = false
            if let commandData = command.data(using: .utf8) {
                success = ZSDKWrapper.send(commandData, toConnection: connection)
            }

            if success {
                self._operationSuccessResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onSettingsComplete",
                    resultValue: true
                )
            } else {
                self._operationErrorResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onSettingsError",
                    code: "SETTINGS_ERROR",
                    message: "Failed to set printer settings",
                    context: ["operation": "setSettings", "command": command]
                )
            }
        }
    }

    private func getLocateValue(args: [String: Any]?, operationId: String, result: @escaping FlutterResult) {
        guard let key = args?["ResourceKey"] as? String else {
            _operationErrorResult(
                operationId: operationId,
                result: result,
                callbackMethod: "onLocateValueError",
                code: "INVALID_ARGUMENT",
                message: "ResourceKey is required")
            return
        }
        connectionQueue.async { [weak self] in
            if key == "connected" {
                self?._operationSuccessResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onLocateValueResult",
                    resultValue: "Connected",
                    arguments: ["value": "Connected"]
                )
                return
            }

            guard let self = self, let connection = self.connection else {
                self?._operationErrorResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onSettingsError",
                    code: "CONNECTION_ERROR",
                    message: "Not connected to printer",
                    arguments: ["error": "Not connected to printer"]
                )
                return
            }

            let value = ZSDKWrapper.getSetting(key, fromConnection: connection)
            self._operationSuccessResult(
                operationId: operationId,
                result: result,
                callbackMethod: "onLocateValueResult",
                resultValue: value ?? "",
                arguments: ["value": value ?? ""]
            )
        }
    }

    private func getSetting(args: [String: Any]?, operationId: String, result: @escaping FlutterResult) {
        guard let setting = args?["setting"] as? String else {
            _operationErrorResult(
                operationId: operationId,
                result: result,
                callbackMethod: "onSettingsError",
                code: "INVALID_ARGUMENT",
                message: "setting is required")
            return
        }
        connectionQueue.async { [weak self] in
            guard let self = self, let connection = self.connection else {
                self?._operationErrorResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onSettingsError",
                    code: "CONNECTION_ERROR",
                    message: "Not connected to printer",
                    arguments: ["error": "Not connected to printer"]
                )
                return
            }

            let value = ZSDKWrapper.getSetting(setting, fromConnection: connection)
            self._operationSuccessResult(
                operationId: operationId,
                result: result,
                callbackMethod: "onSettingsResult",
                resultValue: value ?? "",
                arguments: ["value": value ?? ""]
            )
        }
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
        if parts.count == 2 {
            let portString = parts[1].trimmingCharacters(in: .whitespaces)
            if let port = Int(portString) {
                let ip = String(parts[0]).trimmingCharacters(in: .whitespaces)
                return (ip, port)
            }
        }

        return (address.trimmingCharacters(in: .whitespaces), defaultPort)
    }
    // MARK: - Printer Status Operations

    private func getPrinterStatus(operationId: String, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            guard let self = self else { return }

            if let connection = self.connection {
                let status = ZSDKWrapper.getPrinterStatus(connection)

                self._operationSuccessResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onPrinterStatusResult",
                    resultValue: status,
                    arguments: ["status": status]
                )
            } else {
                let errorStatus: [String: Any] = [
                    "isReadyToPrint": false,
                    "isHeadOpen": false,
                    "isPaperOut": false,
                    "isPaused": false,
                    "isRibbonOut": false,
                    "error": "No printer connection"
                ]

                self._operationSuccessResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onPrinterStatusResult",
                    resultValue: errorStatus,
                    arguments: ["status": errorStatus]
                )
            }
        }
    }

    private func getDetailedPrinterStatus(operationId: String, result: @escaping FlutterResult) {
        connectionQueue.async { [weak self] in
            guard let self = self else { return }

            if let connection = self.connection {
                let detailedStatus = ZSDKWrapper.getDetailedPrinterStatus(connection)

                self._operationSuccessResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onDetailedPrinterStatusResult",
                    resultValue: detailedStatus,
                    arguments: ["detailedStatus": detailedStatus]
                )
            } else {
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

                self._operationSuccessResult(
                    operationId: operationId,
                    result: result,
                    callbackMethod: "onDetailedPrinterStatusResult",
                    resultValue: errorStatus,
                    arguments: ["detailedStatus": errorStatus]
                )
            }
        }
    }

    // MARK: - Operation Manager Utilities

    /// Send success result to operation manager (REQUIRED operationId)
    private func _operationSuccessResult(
        operationId: String,
        result: @escaping FlutterResult,
        callbackMethod: String,
        resultValue: Any?,
        arguments: [String: Any]? = nil) {
        // Create arguments if null and add operationId (thread-safe operation)
        var finalArguments = arguments ?? [:]
        finalArguments["operationId"] = operationId
        
        DispatchQueue.main.async {
            // Send the operation-specific callback with its typed arguments
            self.channel.invokeMethod(callbackMethod, arguments: finalArguments)
            
            // Return the explicit result value
            result(resultValue)
        }
    }

    /// Send error result to operation manager (REQUIRED operationId)
    private func _operationErrorResult(
        operationId: String,
        result: @escaping FlutterResult,
        callbackMethod: String,
        code: String = "OPERATION_ERROR",
        message: String,
        nativeError: Error? = nil,
        context: [String: Any]? = nil,
        arguments: [String: Any]? = nil) {
        // Create arguments if null and add operationId (thread-safe operation)
        var errorArguments = arguments ?? [:]
    
        // Build error info (thread-safe operations)
        errorArguments["operationId"] = operationId
        errorArguments["instanceId"] = self.instanceId
        errorArguments["queue"] = Thread.isMainThread ? "main" : "background"
        errorArguments["message"] = message
        errorArguments["code"] = code
        errorArguments["timestamp"] = ISO8601DateFormatter().string(from: Date())
        errorArguments["nativeStackTrace"] = Thread.callStackSymbols.joined(separator: "\n")
        
        if let nativeError = nativeError {
            errorArguments["nativeError"] = nativeError.localizedDescription
            errorArguments["nativeErrorCode"] = (nativeError as NSError).code
            errorArguments["nativeErrorDomain"] = (nativeError as NSError).domain
            errorArguments["nativeErrorUserInfo"] = (nativeError as NSError).userInfo
        }
        
        if let context = context {
            errorArguments["context"] = context
        }
        
        DispatchQueue.main.async {
            // Send the error callback - error arguments are passed directly as arguments
            self.channel.invokeMethod(callbackMethod, arguments: errorArguments)
            
            // Always return false for errors
            result(false)
        }
    }
}
