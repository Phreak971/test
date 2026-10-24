import CoreLocation
import Foundation

/// Geometry helpers shared by the CarPlay navigator (mirrors lib/core/geo.dart).
enum CarGeo {
  static let earthRadiusM = 6_371_008.8

  /// Decodes a Google-encoded polyline. OSRM `polyline6` uses precision 6.
  /// Malformed input stops decoding instead of crashing.
  static func decodePolyline(_ encoded: String, precision: Int = 6) -> [CLLocationCoordinate2D] {
    let bytes = Array(encoded.utf8)
    let factor = pow(10.0, Double(precision))
    var coords: [CLLocationCoordinate2D] = []
    var index = 0
    var lat = 0
    var lng = 0

    func next() -> Int? {
      var result = 0
      var shift = 0
      while index < bytes.count {
        let b = Int(bytes[index]) - 63
        index += 1
        if b < 0 || shift > 60 { return nil }
        result |= (b & 0x1F) << shift
        shift += 5
        if b < 0x20 {
          return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        }
      }
      return nil
    }

    while index < bytes.count {
      guard let dLat = next(), let dLng = next() else { break }
      lat += dLat
      lng += dLng
      coords.append(CLLocationCoordinate2D(latitude: Double(lat) / factor, longitude: Double(lng) / factor))
    }
    return coords
  }

  static func rad(_ d: Double) -> Double { d * .pi / 180 }
  static func deg(_ r: Double) -> Double { r * 180 / .pi }

  /// Great-circle distance in meters.
  static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    let dLat = rad(b.latitude - a.latitude)
    let dLng = rad(b.longitude - a.longitude)
    let h = sin(dLat / 2) * sin(dLat / 2)
      + cos(rad(a.latitude)) * cos(rad(b.latitude)) * sin(dLng / 2) * sin(dLng / 2)
    return 2 * earthRadiusM * asin(min(1, sqrt(h)))
  }

  /// Initial bearing a → b in degrees [0, 360).
  static func bearing(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    let la1 = rad(a.latitude), la2 = rad(b.latitude)
    let dLng = rad(b.longitude - a.longitude)
    let y = sin(dLng) * cos(la2)
    let x = cos(la1) * sin(la2) - sin(la1) * cos(la2) * cos(dLng)
    let d = deg(atan2(y, x))
    return (d + 360).truncatingRemainder(dividingBy: 360)
  }

  /// cumulative[i] = distance from line[0] to line[i].
  static func cumulativeDistances(_ line: [CLLocationCoordinate2D]) -> [Double] {
    guard !line.isEmpty else { return [0] }
    var out = [Double](repeating: 0, count: line.count)
    for i in 1..<line.count {
      out[i] = out[i - 1] + distance(line[i - 1], line[i])
    }
    return out
  }

  struct Snap {
    var point: CLLocationCoordinate2D
    var segmentIndex: Int
    var fraction: Double
    var distanceFromLineM: Double
  }

  /// Closest point to `p` on the sub-line line[from..<end] (like Dart's
  /// `sublist(from, end)`), using an equirectangular projection around `p`
  /// (fine at street scale). `segmentIndex` is absolute.
  static func snap(_ p: CLLocationCoordinate2D, to line: [CLLocationCoordinate2D], from: Int = 0, end: Int? = nil) -> Snap {
    let lastSeg = line.count - 2
    var best = Snap(point: line.first ?? p, segmentIndex: 0, fraction: 0, distanceFromLineM: .infinity)
    guard lastSeg >= 0 else { return best }
    let start = max(0, min(from, lastSeg))
    let stop = min(lastSeg, (end ?? line.count) - 2)
    guard start <= stop else { return best }
    let cosLat = cos(rad(p.latitude))
    for i in start...stop {
      let a = line[i], b = line[i + 1]
      let ax = (a.longitude - p.longitude) * cosLat, ay = a.latitude - p.latitude
      let bx = (b.longitude - p.longitude) * cosLat, by = b.latitude - p.latitude
      let dx = bx - ax, dy = by - ay
      let len2 = dx * dx + dy * dy
      var t = len2 == 0 ? 0 : -(ax * dx + ay * dy) / len2
      t = min(1, max(0, t))
      let proj = CLLocationCoordinate2D(
        latitude: a.latitude + (b.latitude - a.latitude) * t,
        longitude: a.longitude + (b.longitude - a.longitude) * t)
      let d = distance(p, proj)
      if d < best.distanceFromLineM {
        best = Snap(point: proj, segmentIndex: i, fraction: t, distanceFromLineM: d)
      }
    }
    return best
  }
}
