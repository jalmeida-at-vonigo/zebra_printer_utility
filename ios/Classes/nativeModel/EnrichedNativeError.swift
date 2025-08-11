import Foundation

/// Enriched error information from native operations
/// Preserves structured error data for proper error handling in Dart
@objc public class EnrichedNativeError: NSObject {
    @objc public let message: String
    @objc public let code: String
    @objc public let nativeError: String?
    @objc public let nativeErrorCode: Int?
    @objc public let nativeErrorDomain: String?
    @objc public let context: [String: Any]?
    @objc public let timestamp: String
    @objc public let nativeStackTrace: String?
    @objc public let operationId: String
    @objc public let instanceId: String
    @objc public let queue: String
    
    @objc public init(
        message: String,
        code: String,
        nativeError: String? = nil,
        nativeErrorCode: Int? = nil,
        nativeErrorDomain: String? = nil,
        context: [String: Any]? = nil,
        timestamp: String,
        nativeStackTrace: String? = nil,
        operationId: String,
        instanceId: String,
        queue: String
    ) {
        self.message = message
        self.code = code
        self.nativeError = nativeError
        self.nativeErrorCode = nativeErrorCode
        self.nativeErrorDomain = nativeErrorDomain
        self.context = context
        self.timestamp = timestamp
        self.nativeStackTrace = nativeStackTrace
        self.operationId = operationId
        self.instanceId = instanceId
        self.queue = queue
        super.init()
    }
    
    /// Convert to dictionary for channel communication
    @objc public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "message": message,
            "code": code,
            "timestamp": timestamp,
            "operationId": operationId,
            "instanceId": instanceId,
            "queue": queue,
        ]
        
        if let nativeError = nativeError {
            dict["nativeError"] = nativeError
        }
        
        if let nativeErrorCode = nativeErrorCode {
            dict["nativeErrorCode"] = nativeErrorCode
        }
        
        if let nativeErrorDomain = nativeErrorDomain {
            dict["nativeErrorDomain"] = nativeErrorDomain
        }
        
        if let context = context {
            dict["context"] = context
        }
        
        if let nativeStackTrace = nativeStackTrace {
            dict["nativeStackTrace"] = nativeStackTrace
        }
        
        return dict
    }
    
    /// Create from dictionary received from channel
    @objc public static func fromDictionary(_ dict: [String: Any]) -> EnrichedNativeError? {
        guard let message = dict["message"] as? String,
              let code = dict["code"] as? String,
              let timestamp = dict["timestamp"] as? String,
              let operationId = dict["operationId"] as? String,
              let instanceId = dict["instanceId"] as? String,
              let queue = dict["queue"] as? String else {
            return nil
        }
        
        return EnrichedNativeError(
            message: message,
            code: code,
            nativeError: dict["nativeError"] as? String,
            nativeErrorCode: dict["nativeErrorCode"] as? Int,
            nativeErrorDomain: dict["nativeErrorDomain"] as? String,
            context: dict["context"] as? [String: Any],
            timestamp: timestamp,
            nativeStackTrace: dict["nativeStackTrace"] as? String,
            operationId: operationId,
            instanceId: instanceId,
            queue: queue
        )
    }
}
