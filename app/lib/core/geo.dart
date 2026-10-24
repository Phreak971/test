import 'dart:math' as math;

/// Lightweight coordinate type, independent of the map SDK so core logic stays
/// testable without platform plugins.
class Geo {
  const Geo(this.lat, this.lng);

  final double lat;
  final double lng;

  static const earthRadiusM = 6371008.8;

  Map<String, double> toJson() => {'lat': lat, 'lng': lng};

  factory Geo.fromJson(Map<String, dynamic> j) => Geo((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble());

  /// GeoJSON order.
  List<double> get lngLat => [lng, lat];

  @override
  bool operator ==(Object other) => other is Geo && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'Geo(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})';
}

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;

/// Great-circle distance in metres.
double distanceM(Geo a, Geo b) {
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * Geo.earthRadiusM * math.asin(math.min(1, math.sqrt(h)));
}

/// Initial bearing from [a] to [b], degrees clockwise from north in [0, 360).
double bearingDeg(Geo a, Geo b) {
  final y = math.sin(_rad(b.lng - a.lng)) * math.cos(_rad(b.lat));
  final x = math.cos(_rad(a.lat)) * math.sin(_rad(b.lat)) - math.sin(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.cos(_rad(b.lng - a.lng));
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// Smallest signed difference b - a in degrees, in (-180, 180].
double angleDelta(double a, double b) {
  var d = (b - a) % 360;
  if (d > 180) d -= 360;
  if (d <= -180) d += 360;
  return d;
}

/// Result of snapping a point onto a polyline.
class Snap {
  const Snap({
    required this.point,
    required this.segmentIndex,
    required this.fraction,
    required this.distanceFromLineM,
    required this.alongM,
  });

  final Geo point;

  /// Index i of segment (line[i], line[i+1]).
  final int segmentIndex;

  /// Position within the segment, 0..1.
  final double fraction;
  final double distanceFromLineM;

  /// Distance along the whole line from its start to [point].
  final double alongM;
}

/// Projects [p] onto [line] using a local equirectangular approximation, which
/// is accurate to well under a metre at navigation scales.
Snap snapToLine(Geo p, List<Geo> line, {List<double>? cumulative}) {
  assert(line.length >= 2);
  final cum = cumulative ?? cumulativeDistances(line);
  var best = Snap(point: line.first, segmentIndex: 0, fraction: 0, distanceFromLineM: double.infinity, alongM: 0);
  final cosLat = math.cos(_rad(p.lat));
  for (var i = 0; i < line.length - 1; i++) {
    final a = line[i], b = line[i + 1];
    // Longitude deltas wrapped to (-180, 180] so segments across the
    // antimeridian are measured the short way.
    final segLng = wrapLng(b.lng - a.lng);
    final ax = wrapLng(a.lng - p.lng) * cosLat, ay = a.lat - p.lat;
    final bx = ax + segLng * cosLat, by = b.lat - p.lat;
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : -(ax * dx + ay * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final proj = Geo(a.lat + (b.lat - a.lat) * t, wrapLng(a.lng + segLng * t));
    final d = distanceM(p, proj);
    if (d < best.distanceFromLineM) {
      best = Snap(point: proj, segmentIndex: i, fraction: t, distanceFromLineM: d, alongM: cum[i] + (cum[i + 1] - cum[i]) * t);
    }
  }
  return best;
}

/// cumulative[i] = distance from line[0] to line[i].
List<double> cumulativeDistances(List<Geo> line) {
  final out = List<double>.filled(line.length, 0);
  for (var i = 1; i < line.length; i++) {
    out[i] = out[i - 1] + distanceM(line[i - 1], line[i]);
  }
  return out;
}

/// Decodes a Google/OSRM encoded polyline. OSRM uses precision 5 by default,
/// precision 6 when `geometries=polyline6`.
List<Geo> decodePolyline(String encoded, {int precision = 5}) {
  // Plain arithmetic instead of bit operators: on the web, Dart's bitwise
  // operators work on unsigned 32-bit values, which corrupts negative deltas.
  final factor = math.pow(10, precision).toDouble();
  final out = <Geo>[];
  var index = 0;
  var lat = 0, lng = 0;
  while (index < encoded.length) {
    for (var k = 0; k < 2; k++) {
      // Truncated input: stop at the last complete point instead of throwing.
      if (index >= encoded.length) return out;
      var result = 0, mult = 1, b = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result += (b % 32) * mult;
        mult *= 32;
      } while (b >= 32 && index < encoded.length);
      final delta = result.isOdd ? -((result + 1) ~/ 2) : result ~/ 2;
      if (k == 0) {
        lat += delta;
      } else {
        lng += delta;
      }
    }
    out.add(Geo(lat / factor, lng / factor));
  }
  return out;
}

/// Bounding box [southWest, northEast] of [points].
/// Wraps a longitude (or longitude delta) into (-180, 180].
double wrapLng(double x) {
  final w = (x + 180) % 360 - 180;
  return w == -180 ? 180 : w;
}

/// Bounding box [southWest, northEast] of [points]. When the points straddle
/// the antimeridian the box takes the short way round and `ne.lng` may
/// exceed 180 (MapLibre accepts unwrapped longitudes).
(Geo, Geo) bounds(Iterable<Geo> points) {
  var minLat = 90.0, minLng = 180.0, maxLat = -90.0, maxLng = -180.0;
  var minPos = 360.0, maxPos = 0.0;
  for (final p in points) {
    minLat = math.min(minLat, p.lat);
    maxLat = math.max(maxLat, p.lat);
    minLng = math.min(minLng, p.lng);
    maxLng = math.max(maxLng, p.lng);
    final shifted = p.lng < 0 ? p.lng + 360 : p.lng;
    minPos = math.min(minPos, shifted);
    maxPos = math.max(maxPos, shifted);
  }
  if (maxLng - minLng > 180 && maxPos - minPos < maxLng - minLng) {
    return (Geo(minLat, minPos), Geo(maxLat, maxPos));
  }
  return (Geo(minLat, minLng), Geo(maxLat, maxLng));
}
