import Foundation

class LogUtil {
    enum LogLevel: String {
        case info = "ℹ️ INFO"
        case warn = "⚠️ WARN"
        case error = "❌ ERROR"
        case debug = "🔍 DEBUG"
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }
    
    static func warn(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warn, message: message, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, file: file, function: function, line: line)
    }
    
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        log(level: .debug, message: message, file: file, function: function, line: line)
        #endif
    }
    
    private static func log(level: LogLevel, message: String, file: String, function: String, line: Int) {
        #if DEBUG
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "\(timestamp) \(level.rawValue) [\(fileName):\(line)] \(function) - \(message)"
        
        Swift.print(logMessage)
        #endif
    }
} 