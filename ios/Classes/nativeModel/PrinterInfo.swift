//
//  PrinterInfo.swift
//  zebrautil
//
//  Native model for printer information to ensure type safety
//  between Dart and native communication
//

import Foundation

@objc public class PrinterInfo: NSObject {
    // Required properties
    @objc public let address: String
    @objc public let name: String
    @objc public let status: String
    @objc public let isWifi: Bool
    @objc public let isBluetooth: Bool
    @objc public let connectionType: String
    @objc public let discoveryMethod: String
    
    // Optional properties
    @objc public let model: String?
    @objc public let manufacturer: String?
    @objc public let firmwareRevision: String?
    @objc public let hardwareRevision: String?
    @objc public let displayName: String?
    @objc public let port: Int
    @objc public let dnsName: String?
    
    @objc public init(
        address: String,
        name: String,
        status: String = "Available",
        isWifi: Bool = false,
        isBluetooth: Bool = false,
        connectionType: String = "Unknown",
        discoveryMethod: String = "unknown",
        model: String? = nil,
        manufacturer: String? = "Zebra",
        firmwareRevision: String? = nil,
        hardwareRevision: String? = nil,
        displayName: String? = nil,
        port: Int = 9100,
        dnsName: String? = nil
    ) {
        self.address = address
        self.name = name
        self.status = status
        self.isWifi = isWifi
        self.isBluetooth = isBluetooth
        self.connectionType = connectionType
        self.discoveryMethod = discoveryMethod
        self.model = model
        self.manufacturer = manufacturer
        self.firmwareRevision = firmwareRevision
        self.hardwareRevision = hardwareRevision
        self.displayName = displayName
        self.port = port
        self.dnsName = dnsName
        
        super.init()
    }
    
    /// Convert to dictionary for channel communication
    @objc public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "Address": address,
            "Name": name,
            "Status": status,
            "IsWifi": isWifi,
            "isBluetooth": isBluetooth,
            "connectionType": connectionType,
            "discoveryMethod": discoveryMethod,
            "port": port,
            "brand": manufacturer ?? "Zebra"
        ]
        
        // Add optional properties if present
        if let model = model {
            dict["model"] = model
        }
        if let manufacturer = manufacturer {
            dict["manufacturer"] = manufacturer
        }
        if let firmwareRevision = firmwareRevision {
            dict["firmwareRevision"] = firmwareRevision
        }
        if let hardwareRevision = hardwareRevision {
            dict["hardwareRevision"] = hardwareRevision
        }
        if let displayName = displayName {
            dict["displayName"] = displayName
        }
        if let dnsName = dnsName {
            dict["dnsName"] = dnsName
        }
        
        return dict
    }
    
    /// Create from dictionary received from channel
    @objc public static func fromDictionary(_ dict: [String: Any]) -> PrinterInfo? {
        guard let address = dict["Address"] as? String else { return nil }
        
        return PrinterInfo(
            address: address,
            name: dict["Name"] as? String ?? "Unknown Printer",
            status: dict["Status"] as? String ?? "Available",
            isWifi: dict["IsWifi"] as? Bool ?? false,
            isBluetooth: dict["isBluetooth"] as? Bool ?? false,
            connectionType: dict["connectionType"] as? String ?? "Unknown",
            discoveryMethod: dict["discoveryMethod"] as? String ?? "unknown",
            model: dict["model"] as? String,
            manufacturer: dict["manufacturer"] as? String ?? "Zebra",
            firmwareRevision: dict["firmwareRevision"] as? String,
            hardwareRevision: dict["hardwareRevision"] as? String,
            displayName: dict["displayName"] as? String,
            port: dict["port"] as? Int ?? 9100,
            dnsName: dict["dnsName"] as? String
        )
    }
}