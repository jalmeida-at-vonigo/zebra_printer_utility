import Flutter
import UIKit

public class ZebraUtilPlugin: NSObject, FlutterPlugin {
  private static var registrar: FlutterPluginRegistrar?
  private static var printerInstances: [String: ZebraPrinterInstance] = [:]
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "zebrautil", binaryMessenger: registrar.messenger())
    let instance = ZebraUtilPlugin()
    self.registrar = registrar
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getInstance":
      // Create a new printer instance and register its channel
      let instanceId = "ios_\(UUID().uuidString)"
      if let registrar = ZebraUtilPlugin.registrar {
        let printerInstance = ZebraPrinterInstance(instanceId: instanceId, registrar: registrar)
        ZebraUtilPlugin.printerInstances[instanceId] = printerInstance
      }
      result(instanceId)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
