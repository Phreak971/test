// QA helpers shared by the qa_* test files. Not a test file itself.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:overworld/core/geo.dart';
import 'package:overworld/data/models.dart';
import 'package:overworld/data/routing_service.dart';

RouteResult loadOsrm(String name) => parseOsrmRoute(jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>);

/// Moves [dEastM]/[dNorthM] metres from [o] (local flat-earth approximation).
Geo offset(Geo o, double dEastM, double dNorthM) {
  const mPerDegLat = 111320.0;
  final mPerDegLng = 111320.0 * math.cos(o.lat * math.pi / 180);
  return Geo(o.lat + dNorthM / mPerDegLat, o.lng + dEastM / mPerDegLng);
}

/// Points every [stepM] metres along [line] (same algorithm as navigation_test).
List<Geo> walkLine(List<Geo> line, double stepM) {
  final out = <Geo>[line.first];
  var carry = 0.0;
  for (var i = 0; i < line.length - 1; i++) {
    final a = line[i], b = line[i + 1];
    final seg = distanceM(a, b);
    var d = stepM - carry;
    while (d < seg) {
      final t = d / seg;
      out.add(Geo(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t));
      d += stepM;
    }
    carry = seg - (d - stepM);
  }
  out.add(line.last);
  return out;
}

/// Builds a route that follows [corners] (a polyline in metres relative to
/// [origin]), densified to one vertex every [vertexM] metres like OSRM output.
/// A maneuver step starts at every corner; the last corner is the arrival.
RouteResult syntheticRoute(Geo origin, List<(double, double)> corners, {double vertexM = 20, List<ManeuverKind>? kinds}) {
  final pts = [for (final c in corners) offset(origin, c.$1, c.$2)];
  final geometry = <Geo>[pts.first];
  for (var i = 0; i < pts.length - 1; i++) {
    final seg = distanceM(pts[i], pts[i + 1]);
    final n = math.max(1, (seg / vertexM).ceil());
    for (var k = 1; k <= n; k++) {
      final t = k / n;
      geometry.add(Geo(pts[i].lat + (pts[i + 1].lat - pts[i].lat) * t, pts[i].lng + (pts[i + 1].lng - pts[i].lng) * t));
    }
  }
  final steps = <RouteStep>[];
  for (var i = 0; i < pts.length; i++) {
    final last = i == pts.length - 1;
    final d = last ? 0.0 : distanceM(pts[i], pts[i + 1]);
    steps.add(
      RouteStep(
        kind: i == 0 ? ManeuverKind.depart : (last ? ManeuverKind.arrive : (kinds != null ? kinds[i - 1] : ManeuverKind.right)),
        location: pts[i],
        distanceM: d,
        durationS: d / 12,
        streetName: 'Street $i',
        geometry: last ? [pts[i]] : [pts[i], pts[i + 1]],
      ),
    );
  }
  final total = steps.fold<double>(0, (a, s) => a + s.distanceM);
  return RouteResult(geometry: geometry, distanceM: total, durationS: total / 12, steps: steps);
}
