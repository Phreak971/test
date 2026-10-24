import CoreLocation
import Foundation

// MARK: Route model (mirrors lib/data/models.dart RouteStep / RouteResult)

enum CarManeuverKind: String {
  case depart, arrive, straight, slightLeft, left, sharpLeft, slightRight, right, sharpRight
  case uturn, roundabout, merge, fork, rampLeft, rampRight

  /// OSRM type/modifier → maneuver (same mapping as routing_service.dart).
  static func from(type: String?, modifier: String?) -> CarManeuverKind {
    switch type {
    case "depart": return .depart
    case "arrive": return .arrive
    case "roundabout", "rotary", "roundabout turn", "exit roundabout", "exit rotary": return .roundabout
    case "merge": return .merge
    case "fork":
      switch modifier {
      case "slight left", "left", "sharp left": return .slightLeft
      case "slight right", "right", "sharp right": return .slightRight
      default: return .fork
      }
    case "on ramp", "off ramp":
      if let m = modifier, m.contains("left") { return .rampLeft }
      if let m = modifier, m.contains("right") { return .rampRight }
      return .straight
    default:
      break
    }
    switch modifier {
    case "uturn": return .uturn
    case "sharp right": return .sharpRight
    case "right": return .right
    case "slight right": return .slightRight
    case "sharp left": return .sharpLeft
    case "left": return .left
    case "slight left": return .slightLeft
    default: return .straight
    }
  }
}

struct CarStep {
  /// Maneuver performed at `location`, at the start of this step.
  var kind: CarManeuverKind
  var location: CLLocationCoordinate2D
  var distanceM: Double
  var durationS: Double
  /// Road driven after the maneuver; may be empty.
  var street: String
  var roundaboutExit: Int?
}

struct CarRoute {
  var geometry: [CLLocationCoordinate2D]
  var distanceM: Double
  var durationS: Double
  var steps: [CarStep]
}

enum CarServiceError: LocalizedError {
  case badResponse
  case noRoute(String)

  var errorDescription: String? {
    switch self {
    case .badResponse: return "Unexpected server response"
    case .noRoute(let code): return "No route (\(code))"
    }
  }
}

// MARK: HTTP services (OSRM, Photon, Nominatim)

/// Network calls for the car screen. All completions run on the main queue.
final class CarServices {
  static let shared = CarServices()

  private let session: URLSession
  private let userAgent = "Overworld/1.0"

  private init() {
    let cfg = URLSessionConfiguration.default
    cfg.timeoutIntervalForRequest = 15
    cfg.waitsForConnectivity = false
    session = URLSession(configuration: cfg)
  }

  /// Driving route via OSRM. `headingDeg` biases the start when rerouting.
  @discardableResult
  func route(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, headingDeg: Double? = nil,
             completion: @escaping (Result<CarRoute, Error>) -> Void) -> URLSessionDataTask? {
    let coords = "\(from.longitude),\(from.latitude);\(to.longitude),\(to.latitude)"
    var c = URLComponents(string: "https://router.project-osrm.org/route/v1/driving/\(coords)")
    var items = [
      URLQueryItem(name: "overview", value: "full"),
      URLQueryItem(name: "geometries", value: "polyline6"),
      URLQueryItem(name: "steps", value: "true"),
      URLQueryItem(name: "alternatives", value: "false"),
    ]
    if let h = headingDeg, h >= 0 {
      items.append(URLQueryItem(name: "bearings", value: "\(Int(h.rounded()) % 360),60;"))
      items.append(URLQueryItem(name: "radiuses", value: "50;unlimited"))
    }
    c?.queryItems = items
    guard let url = c?.url else {
      DispatchQueue.main.async { completion(.failure(CarServiceError.badResponse)) }
      return nil
    }
    return getJSON(url) { result in
      completion(result.flatMap { json in
        Result { try Self.parseOsrm(json) }
      })
    }
  }

  /// Location-biased autocomplete via Photon.
  @discardableResult
  func search(_ query: String, near: CLLocationCoordinate2D?,
              completion: @escaping (Result<[CarPlace], Error>) -> Void) -> URLSessionDataTask? {
    var c = URLComponents(string: "https://photon.komoot.io/api/")
    var items = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "10")]
    if let n = near {
      items.append(URLQueryItem(name: "lat", value: String(n.latitude)))
      items.append(URLQueryItem(name: "lon", value: String(n.longitude)))
    }
    c?.queryItems = items
    guard let url = c?.url else {
      DispatchQueue.main.async { completion(.failure(CarServiceError.badResponse)) }
      return nil
    }
    return getJSON(url) { result in
      completion(result.map { Self.parsePhoton($0) })
    }
  }

  /// POIs of an OSM amenity type around `center`, nearest first (Nominatim).
  @discardableResult
  func nearby(amenity: String, center: CLLocationCoordinate2D, language: String,
              completion: @escaping (Result<[CarPlace], Error>) -> Void) -> URLSessionDataTask? {
    let dLat = 0.05
    let dLng = 0.05 / max(0.2, cos(CarGeo.rad(center.latitude)))
    let viewbox = String(format: "%.5f,%.5f,%.5f,%.5f",
                         center.longitude - dLng, center.latitude + dLat,
                         center.longitude + dLng, center.latitude - dLat)
    var c = URLComponents(string: "https://nominatim.openstreetmap.org/search")
    c?.queryItems = [
      URLQueryItem(name: "amenity", value: amenity),
      URLQueryItem(name: "format", value: "jsonv2"),
      URLQueryItem(name: "limit", value: "15"),
      URLQueryItem(name: "bounded", value: "1"),
      URLQueryItem(name: "viewbox", value: viewbox),
      URLQueryItem(name: "accept-language", value: language),
    ]
    guard let url = c?.url else {
      DispatchQueue.main.async { completion(.failure(CarServiceError.badResponse)) }
      return nil
    }
    return getJSON(url) { result in
      completion(result.map { json in
        Self.parseNominatim(json).sorted {
          CarGeo.distance($0.coordinate, center) < CarGeo.distance($1.coordinate, center)
        }
      })
    }
  }

  private func getJSON(_ url: URL, completion: @escaping (Result<Any, Error>) -> Void) -> URLSessionDataTask {
    var req = URLRequest(url: url)
    req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    let task = session.dataTask(with: req) { data, response, error in
      let result: Result<Any, Error>
      if let error = error {
        result = .failure(error)
      } else if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode),
                // OSRM answers 400 with a JSON body for "NoRoute" etc.
                http.statusCode != 400 {
        result = .failure(CarServiceError.badResponse)
      } else if let data = data, let json = try? JSONSerialization.jsonObject(with: data) {
        result = .success(json)
      } else {
        result = .failure(CarServiceError.badResponse)
      }
      DispatchQueue.main.async { completion(result) }
    }
    task.resume()
    return task
  }

  // MARK: Parsing (defensive: bad data → error / skipped entries, never a crash)

  static func parseOsrm(_ json: Any) throws -> CarRoute {
    guard let root = json as? [String: Any] else { throw CarServiceError.badResponse }
    let code = (root["code"] as? String) ?? "Error"
    guard code == "Ok", let r = (root["routes"] as? [[String: Any]])?.first,
          let encoded = r["geometry"] as? String
    else { throw CarServiceError.noRoute(code) }
    let geometry = CarGeo.decodePolyline(encoded, precision: 6)
    var steps: [CarStep] = []
    for leg in (r["legs"] as? [[String: Any]]) ?? [] {
      for s in (leg["steps"] as? [[String: Any]]) ?? [] {
        guard let m = s["maneuver"] as? [String: Any],
              let loc = m["location"] as? [Any], loc.count >= 2,
              let lng = CarParse.double(loc[0]), let lat = CarParse.double(loc[1])
        else { continue }
        steps.append(CarStep(
          kind: CarManeuverKind.from(type: m["type"] as? String, modifier: m["modifier"] as? String),
          location: CLLocationCoordinate2D(latitude: lat, longitude: lng),
          distanceM: CarParse.double(s["distance"]) ?? 0,
          durationS: CarParse.double(s["duration"]) ?? 0,
          street: streetName(s),
          roundaboutExit: (m["exit"] as? NSNumber)?.intValue))
      }
    }
    guard geometry.count >= 2, !steps.isEmpty else { throw CarServiceError.noRoute("EmptyRoute") }
    return CarRoute(
      geometry: geometry,
      distanceM: CarParse.double(r["distance"]) ?? 0,
      durationS: CarParse.double(r["duration"]) ?? 0,
      steps: steps)
  }

  private static func streetName(_ step: [String: Any]) -> String {
    func clean(_ k: String) -> String {
      ((step[k] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    let name = clean("name")
    if !name.isEmpty { return name }
    let ref = clean("ref")
    if !ref.isEmpty { return ref.components(separatedBy: ";").first ?? ref }
    return clean("destinations")
  }

  static func parsePhoton(_ json: Any) -> [CarPlace] {
    guard let root = json as? [String: Any], let features = root["features"] as? [[String: Any]] else { return [] }
    return features.compactMap { f in
      guard let g = f["geometry"] as? [String: Any], let c = g["coordinates"] as? [Any], c.count >= 2,
            let lng = CarParse.double(c[0]), let lat = CarParse.double(c[1])
      else { return nil }
      let p = (f["properties"] as? [String: Any]) ?? [:]
      func str(_ k: String) -> String? {
        guard let v = p[k] as? String, !v.isEmpty else { return nil }
        return v
      }
      let streetLine = [str("street"), str("housenumber")].compactMap { $0 }.joined(separator: " ")
      let name = str("name") ?? (streetLine.isEmpty ? nil : streetLine) ?? str("city") ?? ""
      guard !name.isEmpty else { return nil }
      var parts: [String] = []
      if !streetLine.isEmpty && streetLine != name { parts.append(streetLine) }
      if let city = str("city"), city != name { parts.append(city) }
      if let country = str("country") { parts.append(country) }
      return CarPlace(name: name, lat: lat, lng: lng, address: parts.isEmpty ? nil : parts.joined(separator: ", "))
    }
  }

  static func parseNominatim(_ json: Any) -> [CarPlace] {
    guard let rows = json as? [[String: Any]] else { return [] }
    return rows.compactMap { r in
      guard let lat = CarParse.double(r["lat"]), let lng = CarParse.double(r["lon"]) else { return nil }
      let display = (r["display_name"] as? String) ?? ""
      let comps = display.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
      var name = (r["name"] as? String) ?? ""
      if name.isEmpty { name = comps.first ?? "" }
      guard !name.isEmpty else { return nil }
      let rest = comps.drop(while: { $0 == name }).prefix(3).joined(separator: ", ")
      return CarPlace(id: (r["place_id"] as? NSNumber)?.stringValue, name: name, lat: lat, lng: lng,
                      address: rest.isEmpty ? nil : rest)
    }
  }
}
