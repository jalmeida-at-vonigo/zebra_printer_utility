import Flutter
import UIKit

public class ZebraUtilPlugin: NSObject, FlutterPlugin {
  private var registrar: FlutterPluginRegistrar?
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "zebrautil", binaryMessenger: registrar.messenger())
    let instance = ZebraUtilPlugin()
    instance.registrar = registrar
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getInstance":
      // Return a dummy instance ID for iOS and register the printer channel
      let instanceId = "ios_instance_\(UUID().uuidString)"
      if let registrar = self.registrar {
        _ = ZebraPrinterPlugin.createChannel(for: instanceId, registrar: registrar)
      }
      result(instanceId)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
