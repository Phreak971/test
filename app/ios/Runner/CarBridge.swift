import Flutter
import Foundation

/// `overworld/car` method channel: the phone UI pushes a self-contained
/// snapshot (`sync`) and asks for route previews (`previewRoute`).
/// Contract: lib/car/car_bridge.dart.
final class CarBridgePlugin: NSObject, FlutterPlugin {
  static let channelName = "overworld/car"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = CarBridgePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "sync":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "bad_args", message: "sync expects a map", details: nil))
        return
      }
      CarStore.shared.apply(Self.parseSync(args))
      result(nil)
    case "previewRoute":
      guard let place = CarPlace(channel: call.arguments) else {
        result(FlutterError(code: "bad_args", message: "previewRoute expects {name, lat, lng, address?}", details: nil))
        return
      }
      CarStore.shared.requestPreview(place)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func parseSync(_ a: [String: Any]) -> CarSyncPayload {
    func icons(_ any: Any?) -> [String: Data] {
      guard let m = any as? [String: Any] else { return [:] }
      var out: [String: Data] = [:]
      for (k, v) in m {
        if let t = v as? FlutterStandardTypedData {
          out[k] = t.data
        } else if let d = v as? Data {
          out[k] = d
        }
      }
      return out
    }
    func places(_ any: Any?) -> [CarPlace] {
      ((any as? [Any]) ?? []).compactMap { CarPlace(channel: $0) }
    }
    var voice = CarVoiceConfig()
    if let v = a["voice"] as? [String: Any] {
      voice.id = (v["id"] as? String) ?? voice.id
      voice.name = (v["name"] as? String) ?? voice.name
      voice.pitch = CarParse.double(v["pitch"]) ?? voice.pitch
      voice.rate = CarParse.double(v["rate"]) ?? voice.rate
    }
    return CarSyncPayload(
      lightStyle: (a["lightStyle"] as? String) ?? "",
      darkStyle: (a["darkStyle"] as? String) ?? "",
      lightIcons: icons(a["lightIcons"]),
      darkIcons: icons(a["darkIcons"]),
      alwaysDark: (a["alwaysDark"] as? Bool) ?? false,
      premium: (a["premium"] as? Bool) ?? false,
      unit: (a["unit"] as? String) ?? "metric",
      locale: (a["locale"] as? String) ?? "en",
      voice: voice,
      muted: (a["muted"] as? Bool) ?? false,
      places: places(a["places"]),
      history: places(a["history"]))
  }
}
