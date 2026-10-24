import '../core/geo.dart';
import '../core/http.dart';
import 'models.dart';

class NoRouteException implements Exception {
  const NoRouteException(this.code);

  final String code;

  @override
  String toString() => 'NoRouteException($code)';
}

/// Driving directions from an OSRM server.
class RoutingService {
  RoutingService({JsonClient? client, this.base = 'https://router.project-osrm.org'})
      : _client = client ?? JsonClient(timeout: const Duration(seconds: 15));

  final JsonClient _client;
  final String base;

  Future<RouteResult> route(Geo from, Geo to, {double? headingDeg}) async {
    final coords = '${from.lng},${from.lat};${to.lng},${to.lat}';
    final uri = Uri.parse('$base/route/v1/driving/$coords').replace(queryParameters: {
      'overview': 'full',
      'geometries': 'polyline6',
      'steps': 'true',
      'alternatives': 'false',
      // Prefer continuing in the current direction when rerouting.
      if (headingDeg != null) 'bearings': '${headingDeg.round() % 360},60;',
      if (headingDeg != null) 'radiuses': '50;unlimited',
    });
    final json = await _client.getJson(uri) as Map<String, dynamic>;
    return parseOsrmRoute(json);
  }

  void dispose() => _client.close();
}

/// Parses an OSRM `route` response. Exposed for tests.
RouteResult parseOsrmRoute(Map<String, dynamic> json) {
  final code = json['code'] as String? ?? 'Error';
  final routes = (json['routes'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
  if (code != 'Ok' || routes.isEmpty) throw NoRouteException(code);
  final r = routes.first;
  final geometry = decodePolyline(r['geometry'] as String, precision: 6);
  final steps = <RouteStep>[];
  for (final leg in (r['legs'] as List).cast<Map<String, dynamic>>()) {
    for (final s in (leg['steps'] as List).cast<Map<String, dynamic>>()) {
      final m = (s['maneuver'] as Map).cast<String, dynamic>();
      final loc = (m['location'] as List).cast<num>();
      steps.add(RouteStep(
        kind: maneuverKind(m['type'] as String?, m['modifier'] as String?),
        location: Geo(loc[1].toDouble(), loc[0].toDouble()),
        distanceM: (s['distance'] as num).toDouble(),
        durationS: (s['duration'] as num).toDouble(),
        streetName: _streetName(s),
        geometry: decodePolyline(s['geometry'] as String, precision: 6),
        roundaboutExit: (m['exit'] as num?)?.toInt(),
      ));
    }
  }
  return RouteResult(
    geometry: geometry,
    distanceM: (r['distance'] as num).toDouble(),
    durationS: (r['duration'] as num).toDouble(),
    steps: steps,
  );
}

String _streetName(Map<String, dynamic> step) {
  final name = (step['name'] as String?)?.trim() ?? '';
  final ref = (step['ref'] as String?)?.trim() ?? '';
  if (name.isNotEmpty) return name;
  if (ref.isNotEmpty) return ref.split(';').first;
  final dest = (step['destinations'] as String?)?.trim() ?? '';
  return dest;
}

/// Maps OSRM type/modifier to our maneuver set.
ManeuverKind maneuverKind(String? type, String? modifier) {
  switch (type) {
    case 'depart':
      return ManeuverKind.depart;
    case 'arrive':
      return ManeuverKind.arrive;
    case 'roundabout':
    case 'rotary':
    case 'roundabout turn':
    case 'exit roundabout':
    case 'exit rotary':
      return ManeuverKind.roundabout;
    case 'merge':
      return ManeuverKind.merge;
    case 'fork':
      return switch (modifier) {
        'slight left' || 'left' || 'sharp left' => ManeuverKind.slightLeft,
        'slight right' || 'right' || 'sharp right' => ManeuverKind.slightRight,
        _ => ManeuverKind.fork,
      };
    case 'on ramp':
    case 'off ramp':
      if (modifier != null && modifier.contains('left')) return ManeuverKind.rampLeft;
      if (modifier != null && modifier.contains('right')) return ManeuverKind.rampRight;
      return ManeuverKind.straight;
  }
  return switch (modifier) {
    'uturn' => ManeuverKind.uturn,
    'sharp right' => ManeuverKind.sharpRight,
    'right' => ManeuverKind.right,
    'slight right' => ManeuverKind.slightRight,
    'sharp left' => ManeuverKind.sharpLeft,
    'left' => ManeuverKind.left,
    'slight left' => ManeuverKind.slightLeft,
    _ => ManeuverKind.straight,
  };
}
