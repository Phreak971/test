import CoreLocation
import Foundation
import UIKit

/// A place the car screen can route to (saved place, history entry, search hit).
struct CarPlace: Codable, Equatable {
  var id: String?
  var name: String
  var lat: Double
  var lng: Double
  var address: String?
  var isHome: Bool

  init(id: String? = nil, name: String, lat: Double, lng: Double, address: String? = nil, isHome: Bool = false) {
    self.id = id
    self.name = name
    self.lat = lat
    self.lng = lng
    self.address = address
    self.isHome = isHome
  }

  /// Parses `{id?, name, lat, lng, address?, isHome?}` from the method channel.
  init?(channel any: Any?) {
    guard let d = any as? [String: Any],
          let lat = CarParse.double(d["lat"]), let lng = CarParse.double(d["lng"]),
          CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lng))
    else { return nil }
    let name = (d["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let address = (d["address"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    self.init(id: d["id"] as? String, name: name.isEmpty ? (address ?? "") : name,
              lat: lat, lng: lng, address: address, isHome: (d["isHome"] as? Bool) ?? false)
  }

  var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
}

struct CarVoiceConfig: Codable, Equatable {
  var id: String = "classic"
  var name: String = "Navigator"
  var pitch: Double = 1.0
  var rate: Double = 0.5
}

/// Everything the CarPlay scene needs, persisted so it works without the
/// Flutter UI ever being opened in this process.
struct CarState: Codable {
  /// File names inside the store directory (content-addressed).
  var lightStyleFile: String?
  var darkStyleFile: String?
  var lightIconsDir: String?
  var darkIconsDir: String?

  var alwaysDark = false
  var premium = false
  var unit = "metric"
  var locale = "en"
  var voice = CarVoiceConfig()
  var muted = false
  var places: [CarPlace] = []
  var history: [CarPlace] = []

  var imperial: Bool { unit == "imperial" }
}

/// Decoded `sync` payload (see lib/car/car_bridge.dart).
struct CarSyncPayload {
  var lightStyle: String
  var darkStyle: String
  var lightIcons: [String: Data]
  var darkIcons: [String: Data]
  var alwaysDark: Bool
  var premium: Bool
  var unit: String
  var locale: String
  var voice: CarVoiceConfig
  var muted: Bool
  var places: [CarPlace]
  var history: [CarPlace]
}

enum CarParse {
  static func double(_ any: Any?) -> Double? {
    switch any {
    case let n as NSNumber: return n.doubleValue
    case let d as Double: return d
    case let i as Int: return Double(i)
    case let s as String: return Double(s)
    default: return nil
    }
  }
}

/// Shared store between the Flutter bridge (writer) and the CarPlay scene
/// (reader). Access from the main thread; file IO runs on a private queue.
final class CarStore {
  static let shared = CarStore()

  /// Posted on the main thread after a sync was applied.
  static let didChange = Notification.Name("OverworldCarStoreDidChange")

  /// Posted on the main thread with `object` = `CarPlace` when the phone asks
  /// the car screen to preview a route.
  static let previewRequested = Notification.Name("OverworldCarPreviewRequested")

  private(set) var state: CarState
  /// Set by the CarPlay scene delegate.
  var isCarPlayConnected = false

  private let dir: URL
  private let io = DispatchQueue(label: "app.overworld.car.store", qos: .utility)
  private var iconCache: [String: [String: UIImage]] = [:]
  private var pendingPreview: (place: CarPlace, at: Date)?

  private init() {
    let fm = FileManager.default
    let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
      ?? fm.temporaryDirectory
    dir = base.appendingPathComponent("CarPlay", isDirectory: true)
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    if let data = try? Data(contentsOf: dir.appendingPathComponent("state.json")),
       let saved = try? JSONDecoder().decode(CarState.self, from: data) {
      state = saved
    } else {
      state = CarState()
    }
  }

  /// True once the phone has pushed at least one snapshot.
  var hasSynced: Bool { state.lightStyleFile != nil }

  func styleURL(dark: Bool) -> URL? {
    guard let name = dark ? state.darkStyleFile : state.lightStyleFile else { return nil }
    let url = dir.appendingPathComponent(name)
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  /// Style images (name → @2x image) for the light or dark variant.
  func icons(dark: Bool) -> [String: UIImage] {
    guard let sub = dark ? state.darkIconsDir : state.lightIconsDir else { return [:] }
    if let cached = iconCache[sub] { return cached }
    var out: [String: UIImage] = [:]
    let folder = dir.appendingPathComponent(sub, isDirectory: true)
    let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
    for f in files where f.pathExtension == "png" {
      if let data = try? Data(contentsOf: f), let img = UIImage(data: data, scale: 2) {
        out[f.deletingPathExtension().lastPathComponent] = img
      }
    }
    iconCache[sub] = out
    return out
  }

  // MARK: Writes

  func apply(_ p: CarSyncPayload) {
    var next = state
    next.alwaysDark = p.alwaysDark
    next.premium = p.premium
    next.unit = p.unit == "imperial" ? "imperial" : "metric"
    next.locale = p.locale
    next.voice = p.voice
    next.muted = p.muted
    next.places = p.places
    next.history = p.history

    // Content-addressed names: unchanged content keeps the same file, so the
    // map only reloads its style when it really changed.
    // An empty style (should not happen) keeps the previous one.
    if !p.lightStyle.isEmpty { next.lightStyleFile = "style-light-\(Self.fnv(Data(p.lightStyle.utf8))).json" }
    if !p.darkStyle.isEmpty { next.darkStyleFile = "style-dark-\(Self.fnv(Data(p.darkStyle.utf8))).json" }
    next.lightIconsDir = "icons-light-\(Self.fnv(icons: p.lightIcons))"
    next.darkIconsDir = "icons-dark-\(Self.fnv(icons: p.darkIcons))"

    let dir = self.dir
    io.async { [weak self] in
      let fm = FileManager.default
      if !p.lightStyle.isEmpty, let f = next.lightStyleFile {
        Self.writeIfMissing(Data(p.lightStyle.utf8), to: dir.appendingPathComponent(f))
      }
      if !p.darkStyle.isEmpty, let f = next.darkStyleFile {
        Self.writeIfMissing(Data(p.darkStyle.utf8), to: dir.appendingPathComponent(f))
      }
      Self.writeIcons(p.lightIcons, to: dir.appendingPathComponent(next.lightIconsDir ?? "", isDirectory: true))
      Self.writeIcons(p.darkIcons, to: dir.appendingPathComponent(next.darkIconsDir ?? "", isDirectory: true))
      Self.writeState(next, dir: dir)

      // Remove stale styles / icon folders.
      let keep: Set<String> = [
        "state.json", next.lightStyleFile ?? "", next.darkStyleFile ?? "",
        next.lightIconsDir ?? "", next.darkIconsDir ?? "",
      ]
      for name in (try? fm.contentsOfDirectory(atPath: dir.path)) ?? [] where !keep.contains(name) {
        if name.hasPrefix("style-") || name.hasPrefix("icons-") {
          try? fm.removeItem(at: dir.appendingPathComponent(name))
        }
      }

      DispatchQueue.main.async {
        guard let self = self else { return }
        self.state = next
        self.iconCache = self.iconCache.filter { $0.key == next.lightIconsDir || $0.key == next.darkIconsDir }
        NotificationCenter.default.post(name: CarStore.didChange, object: self)
      }
    }
  }

  /// Car-side mute toggle (the next phone sync may override it).
  func setMuted(_ muted: Bool) {
    state.muted = muted
    let snapshot = state
    let dir = self.dir
    io.async { Self.writeState(snapshot, dir: dir) }
    NotificationCenter.default.post(name: CarStore.didChange, object: self)
  }

  /// Shows the preview now if CarPlay is connected, otherwise keeps it for a
  /// short while so connecting soon after still shows it.
  func requestPreview(_ place: CarPlace) {
    if isCarPlayConnected {
      pendingPreview = nil
      NotificationCenter.default.post(name: CarStore.previewRequested, object: place)
    } else {
      pendingPreview = (place, Date())
    }
  }

  func takePendingPreview() -> CarPlace? {
    defer { pendingPreview = nil }
    guard let p = pendingPreview, Date().timeIntervalSince(p.at) < 15 * 60 else { return nil }
    return p.place
  }

  // MARK: File helpers (io queue)

  private static func writeIfMissing(_ data: Data, to url: URL) {
    guard !FileManager.default.fileExists(atPath: url.path) else { return }
    try? data.write(to: url, options: .atomic)
  }

  private static func writeIcons(_ icons: [String: Data], to folder: URL) {
    let fm = FileManager.default
    guard !fm.fileExists(atPath: folder.path) else { return }
    // Write into a temp folder first so readers never see a half-written set.
    let tmp = folder.deletingLastPathComponent().appendingPathComponent(".tmp-\(UUID().uuidString)", isDirectory: true)
    do {
      try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
      for (name, data) in icons {
        let safe = sanitize(name)
        guard !safe.isEmpty else { continue }
        try data.write(to: tmp.appendingPathComponent("\(safe).png"))
      }
      try fm.moveItem(at: tmp, to: folder)
    } catch {
      try? fm.removeItem(at: tmp)
      NSLog("Overworld CarStore: failed to write icons: \(error)")
    }
  }

  private static func writeState(_ state: CarState, dir: URL) {
    do {
      let data = try JSONEncoder().encode(state)
      try data.write(to: dir.appendingPathComponent("state.json"), options: .atomic)
    } catch {
      NSLog("Overworld CarStore: failed to write state: \(error)")
    }
  }

  private static func sanitize(_ name: String) -> String {
    String(name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }.map(Character.init))
  }

  /// Stable 64-bit FNV-1a, hex encoded (Swift's `hashValue` is per-process).
  private static func fnv(_ data: Data, seed: UInt64 = 0xcbf2_9ce4_8422_2325) -> String {
    String(format: "%016llx", fnvRaw(data, seed: seed))
  }

  private static func fnvRaw(_ data: Data, seed: UInt64) -> UInt64 {
    var h = seed
    for b in data {
      h ^= UInt64(b)
      h = h &* 0x100_0000_01b3
    }
    return h
  }

  private static func fnv(icons: [String: Data]) -> String {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for name in icons.keys.sorted() {
      h = fnvRaw(Data(name.utf8), seed: h)
      h = fnvRaw(icons[name] ?? Data(), seed: h)
    }
    return String(format: "%016llx", h)
  }
}
