import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/core/geo.dart';
import 'package:overworld/core/geo_uri.dart';
import 'package:overworld/core/units.dart';
import 'package:overworld/data/models.dart';
import 'package:overworld/data/routing_service.dart';
import 'package:overworld/data/search_service.dart';
import 'package:overworld/ui/settings/contact_screen.dart';

Map<String, dynamic> fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('geo', () {
    test('distance Berlin to Paris ≈ 878 km', () {
      final d = distanceM(const Geo(52.5200, 13.4050), const Geo(48.8566, 2.3522));
      expect(d / 1000, closeTo(878, 3));
    });

    test('bearing due east is 90', () {
      expect(bearingDeg(const Geo(0, 0), const Geo(0, 1)), closeTo(90, 0.01));
    });

    test('angleDelta wraps', () {
      expect(angleDelta(350, 10), closeTo(20, 1e-9));
      expect(angleDelta(10, 350), closeTo(-20, 1e-9));
    });

    test('decodes known polyline (precision 5)', () {
      final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(pts.length, 3);
      expect(pts[0].lat, closeTo(38.5, 1e-5));
      expect(pts[0].lng, closeTo(-120.2, 1e-5));
      expect(pts[2].lat, closeTo(43.252, 1e-5));
      expect(pts[2].lng, closeTo(-126.453, 1e-5));
    });

    test('snapToLine projects onto segment', () {
      const line = [Geo(0, 0), Geo(0, 0.01)];
      final s = snapToLine(const Geo(0.0001, 0.005), line);
      expect(s.point.lat, closeTo(0, 1e-9));
      expect(s.point.lng, closeTo(0.005, 1e-9));
      expect(s.distanceFromLineM, closeTo(11.1, 0.2));
      expect(s.alongM, closeTo(556, 2));
    });

    test('bounds', () {
      final (sw, ne) = bounds(const [Geo(1, 2), Geo(-1, 5), Geo(3, -4)]);
      expect(sw, const Geo(-1, -4));
      expect(ne, const Geo(3, 5));
    });
  });

  group('units', () {
    test('metric', () {
      expect(formatDistance(42, DistanceUnit.metric), '40 m');
      expect(formatDistance(347, DistanceUnit.metric), '350 m');
      expect(formatDistance(996, DistanceUnit.metric), '1 km');
      expect(formatDistance(2345, DistanceUnit.metric), '2.3 km');
      expect(formatDistance(23450, DistanceUnit.metric), '23 km');
    });

    test('imperial', () {
      expect(formatDistance(100, DistanceUnit.imperial), '330 ft');
      expect(formatDistance(1609.344 * 2.25, DistanceUnit.imperial), '2.3 mi');
    });

    test('duration', () {
      expect(formatDuration(20), '<1 min');
      expect(formatDuration(600), '10 min');
      expect(formatDuration(3600), '1 h');
      expect(formatDuration(3900), '1 h 5 min');
    });

    test('negative and NaN distances clamp to zero', () {
      expect(formatDistance(-5, DistanceUnit.metric), '0 m');
      expect(formatDistance(double.nan, DistanceUnit.metric), '0 m');
    });
  });

  group('osrm', () {
    test('parses a real route', () {
      final r = parseOsrmRoute(fixture('osrm_berlin.json'));
      expect(r.distanceM, greaterThan(1000));
      expect(r.geometry.length, greaterThan(10));
      expect(r.steps.first.kind, ManeuverKind.depart);
      expect(r.steps.last.kind, ManeuverKind.arrive);
      final sum = r.steps.fold<double>(0, (a, s) => a + s.distanceM);
      expect(sum, closeTo(r.distanceM, 5));
      // Geometry stays in Berlin.
      for (final g in r.geometry) {
        expect(g.lat, inInclusiveRange(52.4, 52.6));
        expect(g.lng, inInclusiveRange(13.3, 13.5));
      }
    });

    test('throws NoRoute on error code', () {
      expect(() => parseOsrmRoute({'code': 'NoRoute', 'routes': <Object>[]}), throwsA(isA<NoRouteException>()));
    });

    test('maneuver mapping', () {
      expect(maneuverKind('turn', 'left'), ManeuverKind.left);
      expect(maneuverKind('turn', 'sharp right'), ManeuverKind.sharpRight);
      expect(maneuverKind('roundabout', 'right'), ManeuverKind.roundabout);
      expect(maneuverKind('off ramp', 'slight right'), ManeuverKind.rampRight);
      expect(maneuverKind('fork', 'slight left'), ManeuverKind.slightLeft);
      expect(maneuverKind('continue', 'uturn'), ManeuverKind.uturn);
      expect(maneuverKind('new name', null), ManeuverKind.straight);
    });
  });

  group('search parsing', () {
    test('photon features', () {
      final fc = fixture('photon_search.json');
      final places = (fc['features'] as List).cast<Map<String, dynamic>>().map(photonFeatureToPlace).whereType<Place>().toList();
      expect(places, isNotEmpty);
      expect(places.first.name.toLowerCase(), contains('brandenburg'));
      expect(places.first.location.lat, closeTo(52.516, 0.02));
    });

    test('photon feature without coordinates is skipped', () {
      expect(photonFeatureToPlace({'properties': {'name': 'x'}}), isNull);
    });

    test('nominatim results', () {
      final list = jsonDecode(File('test/fixtures/nominatim_cafes.json').readAsStringSync()) as List;
      final places = list.cast<Map<String, dynamic>>().map(nominatimToPlace).whereType<Place>().toList();
      expect(places, isNotEmpty);
      for (final p in places) {
        expect(p.name, isNotEmpty);
        expect(p.category, 'Cafe');
      }
    });
  });

  group('geo uri', () {
    test('coordinates', () {
      final g = GeoUri.parse('geo:37.786971,-122.399677')!;
      expect(g.point, const Geo(37.786971, -122.399677));
    });

    test('q with label', () {
      final g = GeoUri.parse('geo:0,0?q=34.99,-106.61(Treasure)')!;
      expect(g.point, const Geo(34.99, -106.61));
      expect(g.label, 'Treasure');
    });

    test('free text query', () {
      final g = GeoUri.parse('geo:0,0?q=coffee%20near%20me')!;
      expect(g.point, isNull);
      expect(g.query, 'coffee near me');
    });

    test('invalid', () {
      expect(GeoUri.parse('https://example.com'), isNull);
      expect(GeoUri.parse('geo:0,0'), isNull);
      expect(GeoUri.parse('geo:999,999'), isNull);
    });
  });

  group('contact validation', () {
    test('empty', () => expect(validateContact('', 'hi'), 'empty'));
    test('bad email', () => expect(validateContact('nope', 'hi'), 'email'));
    test('ok', () => expect(validateContact('a@b.co', 'hello'), isNull));
  });

  group('models json', () {
    test('saved place roundtrip', () {
      final p = SavedPlace(id: '1', name: 'Gym', location: const Geo(1, 2), icon: PlaceIcon.gym, createdAt: DateTime(2026, 1, 2), isHome: true, address: 'A st');
      final back = SavedPlace.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back.name, 'Gym');
      expect(back.icon, PlaceIcon.gym);
      expect(back.isHome, isTrue);
      expect(back.location, const Geo(1, 2));
    });

    test('unknown icon falls back to star', () {
      expect(PlaceIcon.parse('nope'), PlaceIcon.star);
    });
  });
}
